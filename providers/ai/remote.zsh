# providers/ai/remote.zsh — Remote-local AI inference (Pi/OpenCode)

zdots_ai_init() {
  # Endpoint for remote local inference (e.g., Raspberry Pi on local network)
  export ZDOTS_AI_ENDPOINT="${ZDOTS_AI_ENDPOINT:-http://raspberrypi.local:11434}"
  export ZDOTS_AI_MODEL="${ZDOTS_AI_MODEL:-llama3.2:3b}"

  # Non-blocking boot-time check for capabilities report
  if curl -s -m 1 "$ZDOTS_AI_ENDPOINT/api/tags" >/dev/null 2>&1; then
    export _ZDOTS_AI_SERVER_UP=1
  else
    export _ZDOTS_AI_SERVER_UP=0
  fi

  _ZDOTS_AI_INITIALIZED=1
}

zdots_ai_infer() {
  local prompt="$1"
  local system="${2:-You are a helpful shell assistant. Concisely parse the provided data.}"

  # Dynamic check
  if ! curl -s -m 3 "$ZDOTS_AI_ENDPOINT/api/tags" >/dev/null 2>&1; then
    echo "ai: error: Remote AI server not responding at $ZDOTS_AI_ENDPOINT" >&2
    export _ZDOTS_AI_SERVER_UP=0
    return 1
  fi
  export _ZDOTS_AI_SERVER_UP=1

  local response
  response=$(jq -nc \
    --arg model "$ZDOTS_AI_MODEL" \
    --arg prompt "$prompt" \
    --arg system "$system" \
    '{model: $model, prompt: $prompt, system: $system, stream: false}' \
    | curl -s -X POST "$ZDOTS_AI_ENDPOINT/api/generate" -d @-)

  if [[ -n "$response" ]]; then
    echo "$response" | jq -r '.response'
  else
    echo "ai: error: received empty response from remote AI" >&2
    return 1
  fi
}

