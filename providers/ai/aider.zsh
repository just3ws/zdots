# providers/ai/aider.zsh — Aider integration wired to the local llama.cpp server.
#
# Aider reads AIDER_* env vars via its auto_env_var_prefix="AIDER_" argparse config,
# so every --flag maps to AIDER_FLAG. All env vars are set in zdots_aider_init so
# they stay consistent with the active ZDOTS_AI_ENDPOINT — no separate config to sync.
#
# Model alias: always "local" (the server alias, never the GGUF filename).
# See AIDER.md for usage guidance and capability boundaries.
#
# Usage:
#   zaider                    # launch aider in current repo
#   zaider --no-auto-commits  # review diffs before committing
#   ZDOTS_AI_ENDPOINT=http://other:8080 zaider  # override endpoint

zdots_aider_init() {
  # AI boundary enforcement — exit 2 if mode=none, exit 1 if endpoint not RFC-1918
  if ! typeset -f zdots_ai_gate > /dev/null 2>&1; then
    # shellcheck source=lib/ai_boundary.bash
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  typeset -f zdots_ai_gate > /dev/null 2>&1 && zdots_ai_gate "zaider"
  typeset -f zdots_assert_local_endpoint > /dev/null 2>&1 \
    && zdots_assert_local_endpoint "${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"

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

  # Redirect history files to XDG state dir to keep chat/input history out of
  # project repos (avoids .aider.input.history leaking into git-tracked dirs).
  local _aider_state="${XDG_STATE_HOME:-$HOME/.local/state}/aider"
  [[ -d "$_aider_state" ]] || mkdir -p "$_aider_state" 2>/dev/null
  export AIDER_INPUT_HISTORY_FILE="${_aider_state}/input.history"
  export AIDER_CHAT_HISTORY_FILE="${_aider_state}/chat.history.md"

  # Disable analytics — no telemetry from a PHI-adjacent machine.
  export AIDER_ANALYTICS=false
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
