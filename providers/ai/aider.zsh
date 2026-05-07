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
  export AIDER_OPENAI_API_KEY="local"   # llama.cpp ignores the key; any non-empty value works

  # Point aider at the model metadata file so it knows the real context window
  # (32768 tokens for the standard profile). Without this aider reports "0 of 0"
  # and cannot budget tokens correctly, causing premature context exhaustion.
  export AIDER_MODEL_METADATA_FILE="${HOME}/.aider.model.metadata.json"

  # Per-repo defaults (edit-format, map-tokens, history limits, etc.) live in
  # .aider.conf.yml in ZDOTDIR. Aider reads it automatically when launched
  # from that directory; zaider() sets AIDER_CONFIG to ensure it's always found.
  export AIDER_CONFIG="${ZDOTDIR}/.aider.conf.yml"
}

# zaider — launch aider wired to local llama.cpp, from any directory.
# Always call zdots_aider_init first so env vars reflect current endpoint.
#
# Workflow tips for 7B context limits:
#   /add file.rb      — add only the file you're editing
#   /drop file.rb     — drop it when done to free context
#   /clear            — wipe history when starting a new task
#   /tokens           — show current token usage breakdown
zaider() {
  zdots_aider_init
  aider "$@"
}

# laid — "Low-load Aider". Runs with lower CPU priority and tighter 
# thread limits to prevent stalling your IDE/Browser on a dev machine.
laid() {
  zdots_aider_init
  
  # 1. 'nice -n 19' ensures the OS prioritizes your IDE/Browser/Builds.
  # 2. 'OMP_NUM_THREADS' and 'GGML_NUM_THREADS' prevents Aider's internal
  #    processes (like mapping) from saturating all CPU cores.
  OMP_NUM_THREADS=2 GGML_NUM_THREADS=2 nice -n 19 aider "$@"
}
