# conf.d/97-zle-ai.zsh — ZLE widgets for inline AI assistance.
#
# Widgets intercept the current buffer and call the local llama.cpp inference
# endpoint directly — no subshell, no fork of zaider/zpi. Fast enough for
# interactive use (~1-3s on 7B). All calls are gated by zdots_ai_gate.
#
# Keybindings:
#   Alt-e   explain the current command buffer
#   Alt-f   suggest a fix for the last failed command
#
# Both widgets append output below the prompt rather than replacing the buffer,
# so the original command is preserved and can be run or edited normally.
#
# Requires: lib/ai_boundary.bash (for mode check), ZDOTS_AI_ENDPOINT (set by
# providers/ai/llama-cpp.zsh). Loads lazily — only wired if llama.cpp is up.

[[ -o interactive ]] || return

_zdots_zle_ai_explain() {
  local cmd="$BUFFER"
  [[ -z "$cmd" ]] && return

  # Load boundary lib lazily; use return-based predicate (exit variants kill the shell).
  if ! typeset -f zdots_ai_gated_endpoint_check > /dev/null 2>&1; then
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  if ! zdots_ai_gated_endpoint_check "zle-ai"; then
    zle -M "ai: unavailable — check ZDOTS_AI_MODE and ZDOTS_AI_ENDPOINT"
    return
  fi
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"

  if ! curl -sf -m 1 "$endpoint/health" >/dev/null 2>&1; then
    zle -M "ai: llama.cpp not responding — run: llama-ctl start"
    return
  fi

  zle -M "ai: explaining..."

  local response
  response=$(jq -nc \
    --arg cmd "$cmd" \
    '{
      model: "local",
      messages: [{role: "user", content: ("Explain this shell command concisely (2-3 sentences max):\n\n" + $cmd)}],
      stream: false,
      max_tokens: 256,
      temperature: 0.1
    }' \
    | curl -sf -m 30 -X POST "$endpoint/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d @- \
    | jq -r '.choices[0].message.content // "no response"' 2>/dev/null)

  zle -M "${response:-ai: no response}"
}

_zdots_zle_ai_fix() {
  local last_cmd="${ZDOTS_LAST_COMMAND:-}"
  local last_exit="${ZDOTS_LAST_EXIT:-}"

  if [[ -z "$last_cmd" || "${last_exit:-0}" == "0" ]]; then
    zle -M "ai: no failed command to fix (run a failing command first)"
    return
  fi

  if ! typeset -f zdots_ai_gated_endpoint_check > /dev/null 2>&1; then
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  if ! zdots_ai_gated_endpoint_check "zle-ai"; then
    zle -M "ai: unavailable — check ZDOTS_AI_MODE and ZDOTS_AI_ENDPOINT"
    return
  fi
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"

  if ! curl -sf -m 1 "$endpoint/health" >/dev/null 2>&1; then
    zle -M "ai: llama.cpp not responding — run: llama-ctl start"
    return
  fi

  zle -M "ai: diagnosing..."

  local response
  response=$(jq -nc \
    --arg cmd "$last_cmd" \
    --arg code "$last_exit" \
    '{
      model: "local",
      messages: [{role: "user", content: ("This shell command failed with exit code " + $code + ":\n\n" + $cmd + "\n\nSuggest a corrected version and one-line explanation.")}],
      stream: false,
      max_tokens: 256,
      temperature: 0.1
    }' \
    | curl -sf -m 30 -X POST "$endpoint/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d @- \
    | jq -r '.choices[0].message.content // "no response"' 2>/dev/null)

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
