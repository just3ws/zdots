# providers/ai/llama-cpp.zsh — llama.cpp implementation for local AI inference
#
# Model storage: $ZDOTS_AI_MODELS_DIR (set in .zdots.env; override for external drive)
# Server lifecycle: managed by bin/llama-server (launchd on macOS)

zdots_ai_init() {
  export ZDOTS_AI_PROFILE="${ZDOTS_AI_PROFILE:-standard}"
  export ZDOTS_AI_MODELS_DIR="${ZDOTS_AI_MODELS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/llama-cpp/models}"

  # Use the unified metadata service to resolve configuration.
  # This populates ZDOTS_AI_ENDPOINT, ZDOTS_AI_MODEL_FILE, etc.
  local _meta_script="${ZDOTDIR:-$HOME/.config/zsh}/lib/metadata.bash"
  if [[ -f "$_meta_script" ]]; then
    eval "$(bash "$_meta_script" env ai)"
  fi

  # Ensure stable variables are set for the provider interface
  export ZDOTS_AI_MODEL="${ZDOTS_AI_MODEL_FILE%%.gguf}"

  # Non-blocking boot-time health check. We do NOT block startup — set a
  # flag in the background so the first explicit `ai` call does a live check.
  export _ZDOTS_AI_SERVER_UP=0
  (
    if curl -sf -m 2 "$ZDOTS_AI_ENDPOINT/health" >/dev/null 2>&1; then
      # Write result to a temp file; parent shell picks it up on next `ai` call.
      printf '1' >| "${TMPDIR:-/tmp}/zdots_ai_up.$$" 2>/dev/null || true
    fi
  ) &!

  _ZDOTS_AI_INITIALIZED=1
}

# zdots_ai_infer PROMPT [SYSTEM_PROMPT]
# Live inference via llama.cpp OpenAI-compatible /v1/chat/completions endpoint.
zdots_ai_infer() {
  local prompt="$1"
  local system="${2:-You are a helpful shell assistant. Concisely parse the provided data.}"

  # Live reachability check (short timeout — fail fast, do not hang the shell)
  if ! curl -sf -m 2 "$ZDOTS_AI_ENDPOINT/health" >/dev/null 2>&1; then
    echo "ai: llama.cpp server not responding at $ZDOTS_AI_ENDPOINT" >&2
    echo "    Start it with: llama-ctl start" >&2
    export _ZDOTS_AI_SERVER_UP=0
    return 1
  fi
  export _ZDOTS_AI_SERVER_UP=1

  local tmp_res; tmp_res=$(mktemp)
  local trace_header=()
  if [[ -n "${TRACEPARENT:-}" ]]; then
    trace_header=( -H "traceparent: ${TRACEPARENT}" )
  fi

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
    | curl -sf -X POST "$ZDOTS_AI_ENDPOINT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        "${trace_header[@]}" \
        -d @- >| "$tmp_res"

  if [[ ! -s "$tmp_res" ]]; then
    echo "ai: empty response from llama.cpp" >&2
    rm -f "$tmp_res"
    return 1
  fi

  local api_error; api_error=$(jq -r '.error.message // empty' "$tmp_res" 2>/dev/null)
  if [[ -n "$api_error" ]]; then
    echo "ai: error: $api_error" >&2
    rm -f "$tmp_res"
    return 1
  fi

  jq -r '.choices[0].message.content // empty' "$tmp_res"
  rm -f "$tmp_res"
}
