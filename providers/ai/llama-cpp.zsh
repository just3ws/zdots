# providers/ai/llama-cpp.zsh — llama.cpp implementation for local AI inference

zdots_ai_init() {
  export ZDOTS_AI_PROFILE="${ZDOTS_AI_PROFILE:-standard}"
  export ZDOTS_AI_ENDPOINT="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"
  
  # Resolve model from central config if yq is available
  # Note: llama.cpp usually loads a single model at startup, so ZDOTS_AI_MODEL 
  # is mostly for metadata/reporting here unless using a multi-model proxy.
  local model="unknown"
  if command -v yq >/dev/null 2>&1; then
    model=$(yq ".profiles.${ZDOTS_AI_PROFILE}.model" "$ZDOTDIR/etc/ai-models.yaml" 2>/dev/null)
    [[ "$model" == "null" ]] && model="unknown"
  fi
  export ZDOTS_AI_MODEL="${ZDOTS_AI_MODEL:-$model}"

  # Non-blocking boot-time check (llama.cpp server /health or /v1/models)
  if curl -s -m 1 "$ZDOTS_AI_ENDPOINT/health" >/dev/null 2>&1; then
    export _ZDOTS_AI_SERVER_UP=1
  else
    export _ZDOTS_AI_SERVER_UP=0
  fi
  
  export _ZDOTS_AI_INITIALIZED=1
}

# zdots_ai_infer PROMPT [SYSTEM_PROMPT]
# High-performance local inference via llama.cpp server (OpenAI-compatible API)
zdots_ai_infer() {
  local prompt="$1"
  local system="${2:-You are a helpful shell assistant. Concisely parse the provided data.}"
  
  # Dynamic check
  if ! curl -s -m 2 "$ZDOTS_AI_ENDPOINT/health" >/dev/null 2>&1; then
    echo "ai: error: llama.cpp server not responding at $ZDOTS_AI_ENDPOINT" >&2
    export _ZDOTS_AI_SERVER_UP=0
    return 1
  fi
  export _ZDOTS_AI_SERVER_UP=1

  # Use a temporary file for the response
  local tmp_res=$(mktemp)
  jq -nc \
    --arg model "$ZDOTS_AI_MODEL" \
    --arg system "$system" \
    --arg user "$prompt" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $user}
      ],
      stream: false,
      temperature: 0.2
    }' \
    | curl -s -X POST "$ZDOTS_AI_ENDPOINT/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d @- > "$tmp_res"
    
  if [[ ! -s "$tmp_res" ]]; then
    echo "ai: error: received empty response from llama.cpp" >&2
    rm -f "$tmp_res"
    return 1
  fi

  # Check for errors in the response
  local api_error=$(jq -r '.error.message // empty' "$tmp_res" 2>/dev/null)
  if [[ -n "$api_error" ]]; then
    echo "ai: error: $api_error" >&2
    rm -f "$tmp_res"
    return 1
  fi

  jq -r '.choices[0].message.content // empty' "$tmp_res"
  rm -f "$tmp_res"
}
