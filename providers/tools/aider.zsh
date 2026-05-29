# providers/tools/aider.zsh — Aider integration wired to the local llama.cpp server.
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
#   ZDOTS_AI_ENDPOINT=http://other:11500 zaider  # override endpoint

zdots_aider_init() {
  # Gate + locality in one call — mode check and endpoint locality together.
  if ! typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1; then
    # shellcheck source=lib/ai_boundary.bash
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1 \
    && zdots_ai_gated_endpoint "zaider" >/dev/null

  # Derive endpoint from the active llama.cpp provider so both always agree.
  # ZDOTS_AI_ENDPOINT is set by providers/ai/llama-cpp.zsh before this runs.
  local _endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}"

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
# Context budget (32k): map ~2k, history ~2k (capped), read files ~2k,
# leaves ~22k for /add. Use /tokens inside to see live breakdown.
#
# Discipline for 7B context limits:
#   /add file.rb      — add only the file being edited (not whole dirs)
#   /drop file.rb     — drop when done to free headroom
#   /clear            — wipe history at the start of each new task
#   /tokens           — confirm headroom before adding large files
zaider() {
  zdots_aider_init

  # Warn when the repo map is stale or unavailable — Aider silently degrades
  # without it, producing edits with no repo awareness.
  if [[ ! -f "${HOME}/.aider.model.metadata.json" ]]; then
    printf 'zaider: warning: ~/.aider.model.metadata.json missing — context window unknown to Aider\n' >&2
  fi

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
