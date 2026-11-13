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
  # Optional first arg "hf" selects the opt-in HuggingFace cloud lane instead of
  # the default local llama.cpp endpoint. Bare `zaider` is unchanged (local).
  local _mode="${1:-local}"

  if [[ "$_mode" == "hf" ]]; then
    # Cloud lane: home-only, scrubber-posture, Keychain key. Fail-closed.
    if ! typeset -f zdots_cloud_lane_guard >/dev/null 2>&1; then
      # shellcheck source=lib/ai_cloud_lane.bash
      [[ -r "${ZDOTDIR}/lib/ai_cloud_lane.bash" ]] && source "${ZDOTDIR}/lib/ai_cloud_lane.bash"
    fi
    typeset -f zdots_cloud_lane_guard >/dev/null 2>&1 \
      || { print -u2 "zaider --hf: cloud lane guard unavailable."; return 1; }
    zdots_cloud_lane_guard "zaider --hf" HF_TOKEN || return $?

    # HuggingFace Inference Router is OpenAI-compatible; aider speaks to it via
    # its openai provider with the base URL overridden. Model is overridable.
    export AIDER_OPENAI_API_BASE="https://router.huggingface.co/v1"
    export AIDER_OPENAI_API_KEY="$ZDOTS_CLOUD_KEY"
    export AIDER_MODEL="${ZDOTS_HF_MODEL:-openai/Qwen/Qwen2.5-Coder-32B-Instruct}"
    unset AIDER_MODEL_METADATA_FILE   # cloud model advertises its own context window
  else
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
  fi

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

  # Peer-aware Capability discovery: env-only for Aider (ZDOTS_AVAILABLE,
  # ZDOTS_PEER_CAPS, ...) so its /run subshells and any zdots tooling it
  # invokes see peer posture. No in-prompt injection — the 7B/32k context
  # budget is too tight to spend on a capability listing (see AIDER.md).
  if ! typeset -f zdots_peer_bootstrap >/dev/null 2>&1; then
    # shellcheck source=lib/peer-bootstrap.bash
    [[ -r "${ZDOTDIR}/lib/peer-bootstrap.bash" ]] && source "${ZDOTDIR}/lib/peer-bootstrap.bash"
  fi
  typeset -f zdots_peer_bootstrap >/dev/null 2>&1 && zdots_peer_bootstrap
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
  # Opt-in cloud lane: `zaider --hf [...]` routes to HuggingFace (home-only,
  # scrubber-posture gated). Bare `zaider` is unchanged — local llama.cpp.
  local _mode="local"
  if [[ "${1:-}" == "--hf" ]]; then
    _mode="hf"; shift
  fi
  zdots_aider_init "$_mode" || return $?

  # Performance Auditing: Log utilization
  zdots_trace_log "ai_query" "tool=zaider,mode=${_mode},args=$*"

  # Warn when the repo map is stale or unavailable — Aider silently degrades
  # without it, producing edits with no repo awareness.
  if [[ ! -f "${HOME}/.aider.model.metadata.json" ]]; then
    printf 'zaider: warning: ~/.aider.model.metadata.json missing — context window unknown to Aider\n' >&2
  fi

  # Weak model (commit messages, chat summaries) on Apple's on-device model,
  # served on loopback for this session only, so llama.cpp keeps its capacity
  # for the main model. Falls back to the local weak model when unavailable.
  # ZDOTS_AIDER_WEAK=local skips it.
  local _fm_dir=""
  if [[ "$_mode" == "local" && "${ZDOTS_AIDER_WEAK:-apple}" == "apple" ]]; then
    _zdots_aider_apple_weak && _fm_dir="$_ZDOTS_AIDER_FM_DIR"
  fi

  if [[ -z "$_fm_dir" ]]; then
    aider "$@"
    return
  fi
  local _rc=0
  AIDER_WEAK_MODEL="openai/system" \
  AIDER_MODEL_SETTINGS_FILE="${_fm_dir}/model.settings.yml" \
  AIDER_MODEL_METADATA_FILE="${_fm_dir}/model.metadata.json" \
    aider "$@" || _rc=$?
  zdots_fm_serve_stop
  rm -rf "$_fm_dir"
  return "$_rc"
}

# _zdots_aider_apple_weak — start the loopback fm server and set
# _ZDOTS_AIDER_FM_DIR to a temp dir holding aider's weak-model settings and
# metadata. Call it directly, not in $(...): the server PID must stay in this
# shell so zaider can stop it.
_zdots_aider_apple_weak() {
  typeset -g _ZDOTS_AIDER_FM_DIR=""
  typeset -f zdots_fm_serve_start >/dev/null 2>&1 \
    || source "${ZDOTDIR}/providers/tools/apple-fm.zsh" 2>/dev/null \
    || return 1
  local rc=0
  zdots_fm_serve_start 2>/dev/null || rc=$?
  if (( rc == 3 )); then
    print -u2 'zaider: Apple weak model refused (fm config could route off this Mac); using the local weak model.'
  fi
  (( rc == 0 )) || return 1
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/zaider-fm.XXXXXX")" || { zdots_fm_serve_stop; return 1; }
  _zdots_fm_aider_files "$ZDOTS_FM_SERVE_PORT" "${dir}/model.settings.yml" \
    "${dir}/model.metadata.json" "${AIDER_MODEL_METADATA_FILE:-}"
  _ZDOTS_AIDER_FM_DIR="$dir"
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
