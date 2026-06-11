# providers/tools/apfel.zsh — Apple Intelligence from the command line.
#
# apfel (homebrew-core `apfel`) runs Apple's on-device foundation model and
# exposes an OpenAI-compatible server (`apfel --serve`, default 127.0.0.1:11434).
# On-device means PHI locality by construction — the prompt never leaves the
# machine, satisfying the same boundary zdots_ai_gated_endpoint enforces for
# llama.cpp. It is seated in the zsynod as @apfel via the keyless-loopback
# `openai` backend (zsynod/members.json).
#
# Usage:
#   zapfel "prompt"            # one-shot, on-device
#   cmd | zapfel "task"        # piped context, same contract as ai-query
#   zapfel --chat              # interactive conversation
#   zapfel --serve             # OpenAI-compat server for the zsynod seat
#
# The server is managed by `brew services start apfel` (operator action);
# this wrapper is the interactive/scripted entry point.

zdots_apfel_init() {
  # Belt-and-suspenders even though inference is on-device: respect the
  # global AI kill switch. mode=none means no AI calls, local included.
  if [[ "${ZDOTS_AI_MODE:-local}" == "none" ]]; then
    print -u2 "zapfel: ZDOTS_AI_MODE=none — AI disabled on this machine"
    return 2
  fi

  # Loopback bind only — never serve Apple Intelligence off-box.
  export APFEL_HOST="${APFEL_HOST:-127.0.0.1}"
  export APFEL_PORT="${APFEL_PORT:-11434}"
}

# zapfel — Apple Intelligence, on-device, zdots-traced.
zapfel() {
  zdots_apfel_init || return $?

  if ! command -v apfel >/dev/null 2>&1; then
    print -u2 'zapfel: apfel not installed — `brew install apfel`.'
    return 127
  fi

  if [[ -n "$1" && "$1" != -* ]]; then
    typeset -f zdots_trace_log >/dev/null 2>&1 \
      && zdots_trace_log "ai_query" "tool=zapfel,prompt=${1[1,128]}"
  else
    typeset -f zdots_trace_log >/dev/null 2>&1 \
      && zdots_trace_log "ai_query" "tool=zapfel,mode=${1:-interactive}"
  fi

  apfel "$@"
}
