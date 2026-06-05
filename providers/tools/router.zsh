# providers/tools/router.zsh — zai engine router (ROUTER Phase 1).
#
# One explicit dispatcher across the local LLM, Pi, and Aider. Local is the
# default; Pi and Aider are opt-in by flag. A local advisory classifier suggests
# a better-fit engine but NEVER switches automatically — no silent escalation.
# Cloud engines (--haiku, --claude-code) are declared for discoverability but
# refuse until their phases land. See ROUTER.md for the full design and policy.
#
# Everything routes through existing bin entrypoints (zdots-ask, zpi, zaider,
# ai-query), so the gate + PHI scrub are inherited and an exit inside a gated
# call can never kill the interactive shell (bins are subprocesses; the
# classifier runs inside command substitution).
#
# Usage:
#   zai "summarize this output"            # local (default)
#   zai --pi "explain the capture flow"    # explore / plan
#   zai --aider "add --json to bin/zsvc"   # edit / patch / commit
#   zai --dry-run --aider "refactor X"     # show the decision, run nothing
#   ZAI_NO_CLASSIFY=1 zai "..."            # skip the advisory classifier

_zai_usage() {
  cat <<'EOF'
zai — engine router (local-first)

Usage:
  zai [ENGINE] [--dry-run] "task"

Engines (default: --local):
  --local         local llama.cpp via zdots-ask         (default)
  --pi            zpi    — explore / read / plan          (local)
  --aider         zaider — edit / patch / commit          (local)
  --haiku         Claude Haiku   (ROUTER Phase 3 — not yet enabled)
  --claude-code   Claude Code    (ROUTER Phase 2 — not yet enabled)

  --dry-run       print the routing decision; run nothing
  -h, --help      this help

The default runs local and prints an advisory suggestion when another engine
fits better. It never escalates automatically. ZAI_NO_CLASSIFY=1 skips advice.
EOF
}

# _zai_classify TASK — print one engine keyword (advisory) or nothing.
# Local-only and exit-safe: callers capture it with $() (a subshell), and it
# bails quietly when the local server is down or ai-query is unavailable.
_zai_classify() {
  local task="$1"
  [[ "${ZAI_NO_CLASSIFY:-0}" == "1" ]] && return 0
  [[ -n "$task" ]] || return 0

  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}"
  curl -sf -m 1 "${endpoint}/health" >/dev/null 2>&1 || return 0

  local aiq="${ZDOTDIR:-$HOME/.config/zsh}/bin/ai-query"
  [[ -x "$aiq" ]] || return 0

  local sys="Classify the software task into exactly ONE keyword from this set: local pi aider haiku claude-code. Rules: local=trivial text/snippet/single command; pi=explore/explain/inspect code; aider=edit/refactor/patch files in a repo; haiku=medium reasoning or ambiguous triage; claude-code=multi-file investigation, architecture, or debugging. Reply with ONLY the keyword, nothing else."

  AIQ_SUPPRESS_RAW_WARN=1 AIQ_TEMPERATURE=0.1 "$aiq" --mode raw --system "$sys" "$task" 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | grep -oE 'claude[- ]?code|local|pi|aider|haiku' \
    | head -n1 \
    | sed 's/claude.*/claude-code/'
}

zai() {
  local engine="" dry=0
  local -a rest
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local)       engine=local;       shift ;;
      --pi)          engine=pi;          shift ;;
      --aider)       engine=aider;       shift ;;
      --haiku)       engine=haiku;       shift ;;
      --claude-code) engine=claude-code; shift ;;
      --dry-run)     dry=1;              shift ;;
      -h|--help)     _zai_usage; return 0 ;;
      --)            shift; rest+=("$@"); break ;;
      -*)            printf 'zai: unknown flag: %s\n' "$1" >&2; _zai_usage >&2; return 2 ;;
      *)             rest+=("$1"); shift ;;
    esac
  done

  local task="${(j: :)rest}"
  # Pi and Aider can launch interactively with no task; the rest need one.
  if [[ -z "$task" && "$engine" != "pi" && "$engine" != "aider" ]]; then
    _zai_usage >&2; return 2
  fi

  # Default = local, with an advisory (never auto-switching) suggestion.
  local suggestion=""
  if [[ -z "$engine" ]]; then
    engine=local
    suggestion="$(_zai_classify "$task")"
  fi

  if (( dry )); then
    printf 'zai: engine=%s\n' "$engine"
    [[ -n "$suggestion" && "$suggestion" != "$engine" ]] && printf 'zai: classifier suggests --%s\n' "$suggestion"
    printf 'zai: task=%s\n' "$task"
    return 0
  fi

  typeset -f zdots_trace_log >/dev/null 2>&1 \
    && zdots_trace_log "ai_query" "tool=zai,engine=${engine}"

  if [[ "$engine" == "local" && -n "$suggestion" && "$suggestion" != "local" ]]; then
    printf 'zai: running local — this task looks better suited to: --%s\n' "$suggestion" >&2
  fi

  local zdotdir="${ZDOTDIR:-$HOME/.config/zsh}"
  case "$engine" in
    local)
      "${zdotdir}/bin/zdots-ask" "$task" ;;
    pi)
      zpi ${task:+"$task"} ;;
    aider)
      if [[ -n "$task" ]]; then zaider --message "$task"; else zaider; fi ;;
    haiku)
      printf 'zai: --haiku needs ROUTER Phase 3 (cloud backend + confirm + scrub). Not enabled yet.\n' >&2
      return 3 ;;
    claude-code)
      printf 'zai: --claude-code needs ROUTER Phase 2 (scrubbed handoff). Not enabled yet.\n' >&2
      return 3 ;;
  esac
}
