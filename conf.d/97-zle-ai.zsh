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

# Shell domain system prompt for ZLE widgets — loaded once on first use.
# Empty string means "not yet loaded"; widgets pass it to zdots_ai_infer_raw.
_ZLE_SYS_PROMPT=""

# Health probe TTL — tracks when the last successful /health check ran.
# 0 means "never checked"; reset to 0 on failure to force recheck on next call.
_ZLE_HEALTH_CHECKED_AT=0

# ---------------------------------------------------------------------------
# _zdots_zle_ai_load — lazy-load the AI Invocation Interface, system prompt,
# and liveness probe. Called at the start of every widget.
#
# - Lib load and system prompt load are idempotent (skip if already done).
# - Server liveness probe runs every call — server may go down between uses.
# - Returns 1 and emits a zle -M message on any failure.
# ---------------------------------------------------------------------------
_zdots_zle_ai_load() {
  # Load AI lib (idempotent).
  if ! typeset -f zdots_ai_infer_raw > /dev/null 2>&1; then
    [[ -r "${ZDOTDIR}/lib/ai-invoke.bash" ]] || {
      zle -M "ai: lib/ai-invoke.bash not found"
      return 1
    }
    source "${ZDOTDIR}/lib/ai-invoke.bash"
    typeset -f zdots_ai_infer_raw > /dev/null 2>&1 || {
      zle -M "ai: zdots_ai_infer_raw unavailable after source"
      return 1
    }
  fi

  # Load shell domain system prompt (idempotent; all ZLE widgets use shell domain).
  if [[ -z "$_ZLE_SYS_PROMPT" ]]; then
    local _sp="${ZDOTDIR}/etc/prompts/zdots-shell.md"
    if [[ -r "$_sp" ]]; then
      _ZLE_SYS_PROMPT=$(cat "$_sp")
    else
      zle -M "ai: zdots-shell.md not found — using generic system prompt"
    fi
  fi

  # Server liveness — probe at most once per 30 s; reset TTL on failure so the
  # next keystroke rechecks immediately after the server recovers.
  local _ep="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}"
  if (( SECONDS - _ZLE_HEALTH_CHECKED_AT > 30 )); then
    if ! curl -sf -m 1 "${_ep}/health" >/dev/null 2>&1; then
      _ZLE_HEALTH_CHECKED_AT=0
      zle -M "ai: llama.cpp not responding — run: llama-ctl start"
      return 1
    fi
    _ZLE_HEALTH_CHECKED_AT=$SECONDS
  fi
}

_zdots_zle_ai_explain() {
  local cmd="$BUFFER"
  [[ -z "$cmd" ]] && return

  _zdots_zle_ai_load || return
  zle -M "ai: explaining..."

  local prompt
  prompt=$(printf 'Explain this shell command concisely (2-3 sentences max):\n\n%s' "$cmd")

  local response
  response=$(
    export AIQ_TEMPERATURE=0.1
    zdots_ai_infer_raw "$prompt" "${_ZLE_SYS_PROMPT:-}" 2>/dev/null
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
  zle -M "ai: diagnosing..."

  local prompt
  prompt=$(printf 'This shell command failed with exit code %s:\n\n%s\n\nSuggest a corrected version and one-line explanation.' "$last_exit" "$last_cmd")

  local response
  response=$(
    export AIQ_TEMPERATURE=0.1
    zdots_ai_infer_raw "$prompt" "${_ZLE_SYS_PROMPT:-}" 2>/dev/null
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
