#!/usr/bin/env zsh
# conf.d/97-zle-ai.zsh — ZLE widgets for inline AI assistance.
#
# Widgets intercept the current buffer and route through the AI Invocation
# Interface (zdots_ai_infer_raw) — gate check, Message Hygiene Pipeline, and
# think-block stripping all apply to widget-triggered inference.
#
# Keybindings:
#   Alt-e   explain the current command buffer
#   Alt-f   suggest a fix for the last failed command
#
# Both widgets append output below the prompt rather than replacing the buffer,
# so the original command is preserved and can be run or edited normally.
#
# Requires: lib/ai-invoke.bash (loaded lazily on first widget use).

[[ -o interactive ]] || return

# ---------------------------------------------------------------------------
# _zdots_zle_ai_load — lazy-load the AI Invocation Interface.
#
# Idempotent: no-ops if zdots_ai_infer_raw is already defined. On failure,
# emits a zle -M error and returns 1 so callers can `|| return` cleanly.
# ---------------------------------------------------------------------------
_zdots_zle_ai_load() {
  typeset -f zdots_ai_infer_raw > /dev/null 2>&1 && return 0
  [[ -r "${ZDOTDIR}/lib/ai-invoke.bash" ]] || {
    zle -M "ai: lib/ai-invoke.bash not found"
    return 1
  }
  source "${ZDOTDIR}/lib/ai-invoke.bash"
  typeset -f zdots_ai_infer_raw > /dev/null 2>&1 || {
    zle -M "ai: zdots_ai_infer_raw unavailable after source"
    return 1
  }
}

_zdots_zle_ai_explain() {
  local cmd="$BUFFER"
  [[ -z "$cmd" ]] && return

  _zdots_zle_ai_load || return

  # Fast server probe — fail in ~1s rather than waiting for the inference timeout.
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"
  if ! curl -sf -m 1 "${endpoint}/health" >/dev/null 2>&1; then
    zle -M "ai: llama.cpp not responding — run: llama-ctl start"
    return
  fi

  zle -M "ai: explaining..."

  local prompt
  prompt=$(printf 'Explain this shell command concisely (2-3 sentences max):\n\n%s' "$cmd")

  local response
  response=$(
    export AIQ_TEMPERATURE=0.1
    zdots_ai_infer_raw "$prompt" 2>/dev/null
  ) || true

  zle -M "${response:-ai: no response}"
}

_zdots_zle_ai_fix() {
  local last_cmd="${ZDOTS_LAST_COMMAND:-}"
  local last_exit="${ZDOTS_LAST_EXIT:-}"

  if [[ -z "$last_cmd" || "${last_exit:-0}" == "0" ]]; then
    zle -M "ai: no failed command to fix (run a failing command first)"
    return
  fi

  _zdots_zle_ai_load || return

  # Fast server probe — fail in ~1s rather than waiting for the inference timeout.
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"
  if ! curl -sf -m 1 "${endpoint}/health" >/dev/null 2>&1; then
    zle -M "ai: llama.cpp not responding — run: llama-ctl start"
    return
  fi

  zle -M "ai: diagnosing..."

  local prompt
  prompt=$(printf 'This shell command failed with exit code %s:\n\n%s\n\nSuggest a corrected version and one-line explanation.' "$last_exit" "$last_cmd")

  local response
  response=$(
    export AIQ_TEMPERATURE=0.1
    zdots_ai_infer_raw "$prompt" 2>/dev/null
  ) || true

  zle -M "${response:-ai: no response}"
}

_zdots_zle_zdash() {
  # Clear the current line and launch zdash in-place.
  # After zdash exits, restore the prompt (zle reset-prompt).
  zle -I   # allow other widgets to run while zdash is alive
  local saved="$BUFFER"
  BUFFER=""
  zle redisplay
  "${ZDOTDIR}/bin/zdash"
  BUFFER="$saved"
  zle reset-prompt
}

zle -N _zdots_zle_ai_explain
zle -N _zdots_zle_ai_fix
zle -N _zdots_zle_zdash

bindkey '\ee' _zdots_zle_ai_explain   # Alt-e: explain buffer
bindkey '\ef' _zdots_zle_ai_fix       # Alt-f: fix last failure
bindkey '\ez' _zdots_zle_zdash        # Alt-z: open zdash task launcher
