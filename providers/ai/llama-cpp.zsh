# providers/ai/llama-cpp.zsh — llama.cpp implementation for local AI inference
#
# Model storage: $ZDOTS_AI_MODELS_DIR (set in .zdots.env; override for external drive)
# Server lifecycle: managed by bin/llama-server (launchd on macOS)

zdots_ai_init() {
  export ZDOTS_AI_PROFILE="${ZDOTS_AI_PROFILE:-standard}"
  export ZDOTS_AI_MODELS_DIR="${ZDOTS_AI_MODELS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/llama-cpp/models}"

  # Resolve endpoint from yaml config so bin/llama-server and this provider
  # always agree. Provider owns this value — overrides any stale export from
  # a previous session (e.g. ZDOTS_AI_ENDPOINT=11434 left from Ollama era).
  # To use a custom port: set ZDOTS_AI_ENDPOINT in .zdots.secrets, which loads
  # AFTER this provider initialises and will win on next shell start.
  local _cfg="${ZDOTDIR:-$HOME/.config/zsh}/etc/ai-models.yaml"
  local _host="127.0.0.1" _port="8080"
  if command -v yq >/dev/null 2>&1 && [[ -r "$_cfg" ]]; then
    local _h _p
    _h=$(yq ".server.host" "$_cfg" 2>/dev/null)
    _p=$(yq ".server.port" "$_cfg" 2>/dev/null)
    [[ "$_h" != "null" && -n "$_h" ]] && _host="$_h"
    [[ "$_p" != "null" && -n "$_p" ]] && _port="$_p"
  fi
  export ZDOTS_AI_ENDPOINT="http://${_host}:${_port}"

  # Resolve active model file from central config (metadata/reporting only —
  # llama.cpp server loads the model from a path set at start time).
  # Set model metadata from yaml. Provider owns this — overwrites stale exports
  # from previous sessions (e.g. old Ollama model names).
  local model_file="unknown"
  if command -v yq >/dev/null 2>&1 && [[ -r "$_cfg" ]]; then
    model_file=$(yq ".profiles.${ZDOTS_AI_PROFILE}.model_file" "$_cfg" 2>/dev/null)
    [[ "$model_file" == "null" || -z "$model_file" ]] && model_file="unknown"
  fi
  export ZDOTS_AI_MODEL="${model_file%%.gguf}"

  # Non-blocking boot-time health check. We do NOT block startup — set a
  # flag in the background so the first explicit `ai` call does a live check.
  export _ZDOTS_AI_SERVER_UP=0
  (
    if curl -sf -m 2 "$ZDOTS_AI_ENDPOINT/health" >/dev/null 2>&1; then
      # Write result to a temp file; parent shell picks it up on next `ai` call.
      printf '1' > "${TMPDIR:-/tmp}/zdots_ai_up.$$" 2>/dev/null || true
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
    echo "    Start it with: llama-server start" >&2
    export _ZDOTS_AI_SERVER_UP=0
    return 1
  fi
  export _ZDOTS_AI_SERVER_UP=1

  local tmp_res; tmp_res=$(mktemp)
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
