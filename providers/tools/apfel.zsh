# providers/tools/apfel.zsh — Apple Intelligence from the command line.
#
# apfel (homebrew-core `apfel`) runs Apple's on-device foundation model and
# exposes an OpenAI-compatible server (`apfel --serve`, default 127.0.0.1:11434).
# The direct CLI also supports interactive, file, MCP, and server modes; those
# can bypass the Message Hygiene Pipeline. `zapfel` therefore exposes only a
# guarded one-shot path: kill switch → normalize → PHI Scrubber → on-device CLI.
#
# Usage:
#   zapfel "prompt"            # one-shot, on-device
#   cmd | zapfel "task"        # piped context, same contract as ai-query
#   zapfel --model-info        # inspect the on-device model
#
# Interactive/chat, file, MCP, and server modes are intentionally not exposed
# through zapfel. Use the low-level `apfel` command only for synthetic data.
#
# The server is managed by `brew services start apfel` (operator action);
# this wrapper is the interactive/scripted entry point.

zdots_apfel_init() {
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

  export APFEL_HOST="${APFEL_HOST:-127.0.0.1}"
  export APFEL_PORT="${APFEL_PORT:-11434}"
}

# zapfel — guarded Apple Intelligence one-shot. Traces metadata only.
zapfel() {
  zdots_apfel_init || return $?

  if ! command -v apfel >/dev/null 2>&1; then
    print -u2 'zapfel: apfel not installed — `brew install apfel`.'
    return 127
  fi

  if (( $# == 1 )) && [[ "$1" == --help || "$1" == -h || "$1" == --version || "$1" == --model-info ]]; then
    apfel "$1"
    return $?
  fi

  if [[ "${1:-}" == -- ]]; then
    shift
  elif [[ "${1:-}" == -* ]]; then
    print -u2 'zapfel: only guarded one-shot prompts are supported; chat, server, file, system, and MCP options are refused.'
    return 2
  fi

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

  # Keep prompt bytes off argv and out of traces. The CLI consumes stdin.
  raw_response="$(print -rn -- "$clean_prompt" | apfel --no-color)" || return 1
  print -rn -- "$raw_response" | zdots_message_hygiene
}
