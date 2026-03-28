# providers/ai/remote.zsh — Remote-local AI inference (Pi/OpenCode)

zdots_ai_init() {
  # Endpoint for remote local inference (e.g., Raspberry Pi on local network)
  export ZDOTS_AI_ENDPOINT="${ZDOTS_AI_ENDPOINT:-http://raspberrypi.local:11434}"
  export ZDOTS_AI_MODEL="${ZDOTS_AI_MODEL:-llama3.2:3b}"

  
  if ! curl -s "$ZDOTS_AI_ENDPOINT/api/tags" >/dev/null 2>&1; then
    export _ZDOTS_AI_SERVER_UP=0
  else
    export _ZDOTS_AI_SERVER_UP=1
  fi
  
  export _ZDOTS_AI_INITIALIZED=1
}

zdots_ai_infer() {
  local prompt="$1"
  local system="${2:-You are a helpful shell assistant. Concisely parse the provided data.}"
  
  if [[ "${_ZDOTS_AI_SERVER_UP:-0}" == "0" ]]; then
    echo "ai: error: Remote AI server not responding at $ZDOTS_AI_ENDPOINT" >&2
    return 1
  fi

  curl -s -X POST "$ZDOTS_AI_ENDPOINT/api/generate" \
    -d "$(printf '{"model":"%s","prompt":"%s","system":"%s","stream":false}' "$ZDOTS_AI_MODEL" "$prompt" "$system")" \
    | jq -r '.response'
}
