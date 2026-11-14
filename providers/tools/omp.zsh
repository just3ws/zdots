# providers/tools/omp.zsh — Oh-My-Pi (omp) multi-role coding agent wired to zdots.
#
# Supports three explicit boundary-enforced lanes:
#   1. `zomp` (default)        → Strictly local llama.cpp (127.0.0.1:11500/v1), safe at Home & Work.
#                                Runs with --offline --no-judge --no-spotlight so zero auxiliary
#                                calls ever leave loopback.
#   2. `zomp --hybrid`         → Home-only (guarded by zdots_cloud_lane_guard). Routes `smol`
#      (or `zomp --or`)          housekeeping to local llama.cpp ($0, zero quota burn) and routes
#                                `default`/`plan`/`slow` across multi-account frontier providers
#                                (or local omp-gateway-ctl at 127.0.0.1:11510/v1).
#   3. `zomp --work-gateway`   → Work-only corporate gateway lane (requires ZDOTS_WORK_AI_GATEWAY_URL
#                                in .zdots.local); keeps `smol` on local llama.cpp and routes
#                                primary reasoning to the employer-sanctioned internal gateway.
#
# See OMP.md for full Home & Work multi-account routing architecture.

zdots_omp_init() {
  local _mode="${1:-local}"
  local _omp_root="${XDG_STATE_HOME:-$HOME/.local/state}/omp"
  local _profile_dir="${_omp_root}/profiles/zdots-${_mode}/agent"
  mkdir -p "${_profile_dir}/sessions" "${_profile_dir}/extensions"

  # Ensure local models.json is present in the profile so `llamacpp/local` is always defined.
  if [[ -r "${ZDOTDIR}/etc/omp/models.local.json" && ! -f "${_profile_dir}/models.json" ]]; then
    cp "${ZDOTDIR}/etc/omp/models.local.json" "${_profile_dir}/models.json"
    chmod 600 "${_profile_dir}/models.json" 2>/dev/null || true
  fi

  # Link the global RTK extension into the isolated profile so every zomp lane uses rtk.
  if [[ -f "$HOME/.omp/agent/extensions/rtk.ts" ]]; then
    ln -sf "$HOME/.omp/agent/extensions/rtk.ts" "${_profile_dir}/extensions/rtk.ts"
  fi

  case "$_mode" in
    hybrid|or)
      if ! typeset -f zdots_cloud_lane_guard >/dev/null 2>&1; then
        # shellcheck source=lib/ai_cloud_lane.bash
        [[ -r "${ZDOTDIR}/lib/ai_cloud_lane.bash" ]] && source "${ZDOTDIR}/lib/ai_cloud_lane.bash"
      fi
      typeset -f zdots_cloud_lane_guard >/dev/null 2>&1 \
        || { print -u2 "zomp --${_mode}: cloud lane guard unavailable."; return 1; }
      if [[ "$_mode" == "or" ]]; then
        zdots_cloud_lane_guard "zomp --or" OPENROUTER_API_KEY || return $?
        export OPENROUTER_API_KEY="$ZDOTS_CLOUD_KEY"
      else
        zdots_cloud_lane_guard "zomp --hybrid" native || return $?
        # Hydrate optional Keychain keys if present (never from .zdots.secrets or .env)
        local _kcmd="${ZDOTS_KEYCHAIN_CMD:-zdots-keychain}"
        if command -v "$_kcmd" >/dev/null 2>&1; then
          local _or_k _gem_k _oai_k _hf_k
          _or_k="$("$_kcmd" get OPENROUTER_API_KEY 2>/dev/null || true)"
          _gem_k="$("$_kcmd" get GEMINI_API_KEY 2>/dev/null || true)"
          _oai_k="$("$_kcmd" get OPENAI_API_KEY 2>/dev/null || true)"
          _hf_k="$("$_kcmd" get HF_TOKEN 2>/dev/null || true)"
          [[ -n "$_or_k" ]] && export OPENROUTER_API_KEY="$_or_k"
          [[ -n "$_gem_k" ]] && export GEMINI_API_KEY="$_gem_k"
          [[ -n "$_oai_k" ]] && export OPENAI_API_KEY="$_oai_k"
          [[ -n "$_hf_k" ]] && export HF_TOKEN="$_hf_k"
        fi
      fi
      ;;
    work-gateway)
      if [[ -z "${ZDOTS_WORK_AI_GATEWAY_URL:-}" ]]; then
        print -u2 "zomp --work-gateway: set ZDOTS_WORK_AI_GATEWAY_URL in .zdots.local first."
        return 2
      fi
      ;;
    *)
      if ! typeset -f zdots_ai_gated_endpoint >/dev/null 2>&1; then
        [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
      fi
      typeset -f zdots_ai_gated_endpoint >/dev/null 2>&1 \
        && zdots_ai_gated_endpoint "zomp" >/dev/null
      ;;
  esac

  if ! typeset -f zdots_peer_bootstrap >/dev/null 2>&1; then
    # shellcheck source=lib/peer-bootstrap.bash
    [[ -r "${ZDOTDIR}/lib/peer-bootstrap.bash" ]] && source "${ZDOTDIR}/lib/peer-bootstrap.bash"
  fi
  typeset -f zdots_peer_bootstrap >/dev/null 2>&1 && zdots_peer_bootstrap

  export PI_TELEMETRY=0
  export PI_CODING_AGENT_DIR="$_profile_dir"
  if [[ "$_mode" != "hybrid" ]]; then
    export PI_SMOL_MODEL="${PI_SMOL_MODEL:-llamacpp/local}"
  fi
}

zomp() {
  local _mode="local"
  local _or_model=""
  local -a _omp_args=()

  case "${1:-}" in
    --hybrid)
      _mode="hybrid"
      shift
      ;;
    --or)
      _mode="or"
      shift
      _or_model="${ZDOTS_OR_MODEL:-}"
      [[ -n "$_or_model" ]] || { print -u2 "zomp --or: set ZDOTS_OR_MODEL explicitly; no default cloud model is selected."; return 2; }
      if [[ "${_or_model:l}" == *anthropic* || "${_or_model:l}" == *claude* ]]; then
        print -u2 "zomp --or: Anthropic models are disabled; choose a different ZDOTS_OR_MODEL."
        return 2
      fi
      ;;
    --work-gateway)
      _mode="work-gateway"
      shift
      ;;
  esac

  zdots_omp_init "$_mode" || return $?

  case "$_mode" in
    local)
      _omp_args+=(
        --config "${ZDOTDIR}/etc/omp/config.local.yml"
        --model "llamacpp/local"
        --smol "llamacpp/local"
        --slow "llamacpp/local"
        --plan "llamacpp/local"
        --offline
        --no-judge
        --no-spotlight
      )
      ;;
    hybrid)
      _omp_args+=(
        --config "${ZDOTDIR}/etc/omp/config.home.yml"
      )
      ;;
    or)
      _omp_args+=(
        --config "${ZDOTDIR}/etc/omp/config.home.yml"
        --model "openrouter/${_or_model}"
        --smol "llamacpp/local"
      )
      ;;
    work-gateway)
      _omp_args+=(
        --config "${ZDOTDIR}/etc/omp/config.local.yml"
        --smol "llamacpp/local"
        --offline
        --no-judge
        --no-spotlight
      )
      ;;
  esac

  [[ -r "${ZDOTDIR}/OMP.md" ]] \
    && _omp_args+=(--append-system-prompt "${ZDOTDIR}/OMP.md")

  [[ -r "${PWD}/AGENTS.md" ]] \
    && _omp_args+=(--append-system-prompt "${PWD}/AGENTS.md")

  local _brief_file
  _brief_file=$(mktemp 2>/dev/null) || true
  if [[ -n "$_brief_file" ]]; then
    "${ZDOTDIR}/bin/pi-ctx-brief" > "$_brief_file" 2>/dev/null || true
    [[ -s "$_brief_file" ]] \
      && _omp_args+=(--append-system-prompt "$_brief_file")
  fi

  if [[ -n "${1:-}" ]]; then
    zdots_trace_log "ai_query" "tool=zomp,lane=${_mode},prompt=${1[1,128]}"
  else
    zdots_trace_log "ai_query" "tool=zomp,lane=${_mode},mode=interactive"
  fi

  omp "${_omp_args[@]}" "$@"

  [[ -n "$_brief_file" ]] && rm -f "$_brief_file"
}
