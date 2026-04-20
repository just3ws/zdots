# providers/ai/aider.zsh — Aider integration wired to the local llama.cpp server.
#
# Aider reads AIDER_OPENAI_API_BASE and AIDER_OPENAI_API_KEY at startup.
# These are set here so they are always consistent with the active llama.cpp
# endpoint — no separate config file to keep in sync.
#
# Model alias: always "local" (the server alias, never the GGUF filename).
# See docs/aider.md for usage guidance and capability boundaries.
#
# Usage:
#   zaider                    # launch aider in current repo
#   zaider --no-auto-commits  # review diffs before committing
#   zaider --architect        # architect mode (two-model: plan + edit)
#   ZDOTS_AI_ENDPOINT=http://other:8080 zaider  # override endpoint

zdots_aider_init() {
  # Derive endpoint from the active llama.cpp provider so both always agree.
  # ZDOTS_AI_ENDPOINT is set by providers/ai/llama-cpp.zsh before this runs.
  local _endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"

  export AIDER_OPENAI_API_BASE="${_endpoint}/v1"
  export AIDER_OPENAI_API_KEY="local"          # llama.cpp ignores the key; any non-empty value works
  export AIDER_MODEL="openai/local"            # "openai/" prefix = OpenAI-compatible provider
  export AIDER_WEAK_MODEL="openai/local"       # used for commit messages and summarisation

  # Disable aider's update check and analytics — we manage versions via uv.
  export AIDER_NO_CHECK_UPDATE=1
  export AIDER_ANALYTICS=false

  # Sensible defaults for local inference:
  #   - no-auto-commits: local models can produce noisy diffs; review before commit
  #   - max-chat-history-tokens: keep context tight for 7B model (8k is comfortable)
  #   - no-show-model-warnings: the "local" alias is intentionally not in aider's cloud registry
  export AIDER_AUTO_COMMITS=false
  export AIDER_MAX_CHAT_HISTORY_TOKENS=8000
  export AIDER_SHOW_MODEL_WARNINGS=false
}

# zaider — launch aider wired to local llama.cpp, from any directory.
# Always call zdots_aider_init first so env vars reflect current endpoint.
zaider() {
  zdots_aider_init
  aider "$@"
}
