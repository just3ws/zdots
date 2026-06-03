# conf.d/72-ai-function.zsh - interactive AI pipe helper

# AI Pattern Pipe: pipe any output into local AI for inference/parsing.
# Usage: cat log.txt | ai "Find all unique error codes"
ai() {
  if [[ -z "$1" || "$1" == "--help" || "$1" == "-h" ]]; then
    local _ai_server_status
    _ai_server_status=$(llama-ctl health 2>/dev/null && echo "up" || echo "down - run: llama-ctl start")
    cat <<EOF
Usage:
  ai <prompt>                    Direct prompt
  <command> | ai <prompt>        Pipe command output into AI
  ai <prompt> < file             Redirect file into AI

Examples:
  ai "What does SIGPIPE mean?"
  git diff | ai "Write a commit message"
  cat error.log | ai "Find the root cause"
  history-analyze --ai           AI-powered shell history analysis

Runtime:  llama.cpp (local, ${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500})
Model:    ${ZDOTS_AI_MODEL:-unknown}   [profile: ${ZDOTS_AI_PROFILE:-standard}]
Status:   ${_ai_server_status}

Manage:
  llama-ctl status               server status
  llama-ctl start                start inference server
  llama-ctl stop                 stop inference server
  llama-ctl logs                 tail server log
  llama-ctl model-download       download/update model
  llama-ctl model-prune          reclaim disk (remove non-active GGUFs)

Agent/subprocess use (works outside interactive shell):
  ai-query <prompt>      bin/ai-query - same inference, any shell context
EOF
    return 0
  fi

  local input
  if [[ ! -t 0 ]]; then
    input=$(cat)
  fi

  if [[ -n "$(command -v zdots_ai_infer)" ]]; then
    local output
    if [[ -n "$input" ]]; then
      output=$(zdots_ai_infer "Data: $input\n\nTask: $1")
    else
      output=$(zdots_ai_infer "$1")
    fi
    local _ai_status=$?

    if command -v otel-cli >/dev/null 2>&1; then
      (
        otel-cli span \
          --name "ai.infer" \
          --attrs "model=${ZDOTS_AI_MODEL:-unknown},provider=${ZDOTS_SERVICE_AI:-none}" \
          --force-trace-id "$ZDOTS_TRACE_ID" \
          --force-span-id "$ZDOTS_SPAN_ID" \
          $( [[ $_ai_status -ne 0 ]] && echo "--status error" ) \
          >/dev/null 2>&1
      ) &!
    fi

    echo "$output"
    return $_ai_status
  else
    echo "ai: error: no AI inference provider configured or initialized" >&2
    return 1
  fi
}

return 0
