# providers/ai/ollama.zsh — Ollama implementation for local AI inference

zdots_ai_init() {
  export ZDOTS_AI_MODEL="${ZDOTS_AI_MODEL:-llama3.2:3b}" # Fast, lightweight default

  
  # Check if Ollama is installed
  if ! command -v ollama >/dev/null 2>&1; then
    return 1
  fi
  
  # Optional: check if server is running
  if ! curl -s "http://localhost:11434/api/tags" >/dev/null 2>&1; then
    # We don't fail init, but we'll report status in capabilities
    export _ZDOTS_AI_SERVER_UP=0
  else
    export _ZDOTS_AI_SERVER_UP=1
  fi
  
  export _ZDOTS_AI_INITIALIZED=1
}

# zdots_ai_infer PROMPT [SYSTEM_PROMPT]
# High-performance local inference via Ollama
zdots_ai_infer() {
  local prompt="$1"
  local system="${2:-You are a helpful shell assistant. Concisely parse the provided data.}"
  
  if [[ "${_ZDOTS_AI_SERVER_UP:-0}" == "0" ]]; then
    echo "ai: error: Ollama server not running on localhost:11434" >&2
    return 1
  fi

  curl -s -X POST "http://localhost:11434/api/generate" \
    -d "$(printf '{"model":"%s","prompt":"%s","system":"%s","stream":false}' "$ZDOTS_AI_MODEL" "$prompt" "$system")" \
    | jq -r '.response'
}
