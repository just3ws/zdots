# providers/ai/ollama.zsh — Ollama implementation for local AI inference

zdots_ai_init() {
  export ZDOTS_AI_MODEL="${ZDOTS_AI_MODEL:-llama3.2:3b}"
  export ZDOTS_AI_ENDPOINT="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11434}"

  # Non-blocking boot-time check for capabilities report
  if curl -s -m 1 "$ZDOTS_AI_ENDPOINT/api/tags" >/dev/null 2>&1; then
    export _ZDOTS_AI_SERVER_UP=1
  else
    export _ZDOTS_AI_SERVER_UP=0
  fi

  export _ZDOTS_AI_INITIALIZED=1
}

# zdots_ai_infer PROMPT [SYSTEM_PROMPT]
zdots_ai_infer() {
  local prompt="$1"
  local system="${2:-You are a helpful shell assistant. Concisely parse the provided data.}"

  # Dynamic check: try to connect with a short timeout
  if ! curl -s -m 2 "$ZDOTS_AI_ENDPOINT/api/tags" >/dev/null 2>&1; then
    echo "ai: error: Ollama server not responding at $ZDOTS_AI_ENDPOINT" >&2
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

  if [[ -z "$response" ]]; then
    echo "ai: error: received empty response from Ollama" >&2
    return 1
  fi

  # Check for API-level errors
  local api_error=$(echo "$response" | jq -r '.error // empty')
  if [[ -n "$api_error" ]]; then
    echo "ai: error: $api_error" >&2
    if [[ "$api_error" == *"not found"* ]]; then
      echo "suggestion: run 'ollama pull $ZDOTS_AI_MODEL'" >&2
    fi
    return 1
  fi

  echo "$response" | jq -r '.response'
}
