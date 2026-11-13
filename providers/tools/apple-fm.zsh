# providers/tools/apple-fm.zsh — Apple Intelligence through Apple's fm CLI.
#
# macOS 27 ships /usr/bin/fm, which runs Apple's on-device foundation model
# (~3B, ~8K-token context, no disk cost) and can serve it over an
# OpenAI-compatible API. fm can also reach models off this Mac: Private Cloud
# Compute (`--model pcc`) or any Chat Completions URL (`--model-provider`).
# Everything here is locked to the on-device model:
#   - every call passes `--model system`; never pcc, never --model-provider
#   - zdots_fm_guard refuses when fm's config names a default provider or a
#     default model other than system
#   - `fm serve` binds 127.0.0.1 only, for the life of one zaider session
#
# `zapfel` is the guarded one-shot path: kill switch → normalize → PHI
# Scrubber → on-device model. fm's chat, image, tool, and server options are
# not exposed through it.
#
# Usage:
#   zapfel "prompt"            # one-shot, on-device
#   cmd | zapfel "task"        # piped context, same contract as ai-query
#   zapfel --model-info        # show fm's models and configuration
#
# One-time setup: `sudo fm license` (machine-wide; check with IT on a managed Mac).

# zdots_fm_guard — succeed only when the on-device model is usable and fm
# cannot route a call off this Mac. 127 = unavailable, 3 = refused.
zdots_fm_guard() {
  local fm="${ZDOTS_FM_BIN:-/usr/bin/fm}" provider model
  if [[ ! -x "$fm" ]]; then
    print -u2 "apple-fm: $fm not found (needs macOS 27 with Apple Intelligence)."
    return 127
  fi
  if ! NO_COLOR=1 "$fm" models 2>/dev/null | grep -q '✓ system'; then
    print -u2 'apple-fm: on-device model unavailable (Apple Intelligence off, unsupported Mac, or `sudo fm license` not accepted).'
    return 127
  fi
  # Fail closed: an empty answer counts as "set".
  provider="$(NO_COLOR=1 "$fm" config get default-model-provider 2>/dev/null)"
  model="$(NO_COLOR=1 "$fm" config get default-model 2>/dev/null)"
  if [[ "$provider" != "(none)" ]]; then
    print -u2 "apple-fm: refusing — fm's default-model-provider is '${provider}', so prompts could leave this Mac (see: fm config list)."
    return 3
  fi
  if [[ "$model" != "(none)" && "$model" != "system" ]]; then
    print -u2 "apple-fm: refusing — fm's default-model is '${model}', not the on-device model (see: fm config list)."
    return 3
  fi
}

zdots_apple_fm_init() {
  local zdots_root="${ZDOTDIR:-$HOME/.config/zsh}"

  if ! typeset -f zdots_ai_gate_check >/dev/null 2>&1; then
    [[ -r "$zdots_root/lib/ai_boundary.bash" ]] && source "$zdots_root/lib/ai_boundary.bash"
  fi
  if ! typeset -f zdots_ai_gate_check >/dev/null 2>&1; then
    print -u2 'zapfel: AI boundary unavailable — refusing inference.'
    return 1
  fi
  if ! zdots_ai_gate_check zapfel; then
    print -u2 "zapfel: ZDOTS_AI_MODE=none — AI disabled on this machine"
    return 2
  fi

  # Load the canonical hygiene functions in this order. message_hygiene.bash
  # delegates to phi_scrub and stays fail-closed if the Go PHI Scrubber fails.
  if ! typeset -f zdots_message_hygiene >/dev/null 2>&1; then
    [[ -r "$zdots_root/lib/phi_scrubber.bash" ]] && source "$zdots_root/lib/phi_scrubber.bash"
    [[ -r "$zdots_root/lib/message_hygiene.bash" ]] && source "$zdots_root/lib/message_hygiene.bash"
  fi
  if ! typeset -f zdots_message_hygiene >/dev/null 2>&1 || ! typeset -f phi_scrub >/dev/null 2>&1; then
    print -u2 'zapfel: Message Hygiene Pipeline unavailable — refusing inference.'
    return 1
  fi
}

# zapfel — guarded Apple Intelligence one-shot. Traces metadata only.
zapfel() {
  local fm="${ZDOTS_FM_BIN:-/usr/bin/fm}"

  case "${1:-}" in
    -h|--help)
      print 'usage: zapfel "prompt"  |  command | zapfel "task"  |  zapfel --model-info'
      return 0 ;;
    --model-info)
      zdots_fm_guard
      NO_COLOR=1 "$fm" models; NO_COLOR=1 "$fm" config list
      return $? ;;
    --) shift ;;
    -*)
      print -u2 'zapfel: only guarded one-shot prompts are supported; fm options are refused.'
      return 2 ;;
  esac

  zdots_apple_fm_init || return $?
  zdots_fm_guard || return $?

  local task="$*" piped="" raw_prompt="" clean_prompt="" raw_response=""
  if [[ ! -t 0 ]]; then
    piped="$(cat)" || return 1
  fi
  if [[ -n "$piped" && -n "$task" ]]; then
    raw_prompt=$'Input:\n'"$piped"$'\n\nTask: '"$task"
  elif [[ -n "$piped" ]]; then
    raw_prompt="$piped"
  else
    raw_prompt="$task"
  fi
  if [[ -z "$raw_prompt" ]]; then
    print -u2 'usage: zapfel "prompt"  |  command | zapfel "task"'
    return 2
  fi

  clean_prompt="$(print -rn -- "$raw_prompt" | zdots_message_hygiene)" || {
    print -u2 'zapfel: input hygiene failed — refusing inference.'
    return 1
  }
  if [[ -z "$clean_prompt" ]]; then
    print -u2 'zapfel: prompt is empty after normalization.'
    return 2
  fi

  typeset -f zdots_trace_log >/dev/null 2>&1 \
    && zdots_trace_log "ai_query" "tool=zapfel,mode=guarded,input_bytes=${#clean_prompt}"

  # Keep prompt bytes off argv and out of traces. fm reads the prompt on stdin.
  raw_response="$(print -rn -- "$clean_prompt" | NO_COLOR=1 "$fm" respond --model system --no-stream)" || return 1
  print -rn -- "$raw_response" | zdots_message_hygiene
}

# zdots_fm_serve_start — start `fm serve` on a free loopback port (44611–44630)
# for one session. Sets ZDOTS_FM_SERVE_PID and ZDOTS_FM_SERVE_PORT. Starts
# nothing and returns the guard's status when the guard refuses.
zdots_fm_serve_start() {
  zdots_fm_guard || return $?
  local fm="${ZDOTS_FM_BIN:-/usr/bin/fm}" port="" p i
  for p in {44611..44630}; do
    lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 || { port="$p"; break; }
  done
  if [[ -z "$port" ]]; then
    print -u2 'apple-fm: no free loopback port in 44611–44630.'
    return 1
  fi

  NO_COLOR=1 "$fm" serve --host 127.0.0.1 --port "$port" >/dev/null 2>&1 &!
  typeset -g ZDOTS_FM_SERVE_PID=$! ZDOTS_FM_SERVE_PORT="$port"
  for i in {1..20}; do
    curl -sf -m 1 "http://127.0.0.1:${port}/health" >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  print -u2 "apple-fm: fm serve did not come up on 127.0.0.1:${port}."
  zdots_fm_serve_stop
  return 1
}

zdots_fm_serve_stop() {
  [[ -n "${ZDOTS_FM_SERVE_PID:-}" ]] && kill "$ZDOTS_FM_SERVE_PID" 2>/dev/null
  unset ZDOTS_FM_SERVE_PID ZDOTS_FM_SERVE_PORT
}

# _zdots_fm_aider_files PORT SETTINGS METADATA BASE_METADATA — write the aider
# files that route the weak model (openai/system) to the loopback fm server.
# Metadata merges BASE_METADATA (if present) so the main model's entry stays.
_zdots_fm_aider_files() {
  local port="$1" settings="$2" metadata="$3" base="$4"
  # fm serve streams unless the request says "stream": false; litellm omits
  # the field for non-streaming calls, so send it explicitly.
  cat > "$settings" <<EOF
- name: openai/system
  extra_params:
    api_base: http://127.0.0.1:${port}/v1
    api_key: local
    extra_body:
      stream: false
EOF
  # fm's on-device context is ~8K tokens, shared by prompt and reply.
  local entry='{"openai/system":{"max_input_tokens":6144,"max_output_tokens":2048,"litellm_provider":"openai","mode":"chat"}}'
  if [[ -r "$base" ]]; then
    jq --argjson e "$entry" '. + $e' "$base" > "$metadata"
  else
    print -r -- "$entry" > "$metadata"
  fi
}
