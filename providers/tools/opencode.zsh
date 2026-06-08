# providers/tools/opencode.zsh — OpenCode wired to the local llama.cpp server.
#
# OpenCode (homebrew-core `opencode`) is a terminal agentic coding agent, seated
# in the synod as a local executing member per committed P18. This wrapper pins
# it to the local OpenAI-compatible endpoint and disables session sharing, so it
# behaves like zaider/zpi under PHI Operating Mode.
#
# SAFETY (fail-closed): zdots_ai_gated_endpoint enforces ZDOTS_AI_MODE=local and
# a loopback/RFC-1918 endpoint before launch. With no cloud keys set, a
# misconfigured provider FAILS (no model reachable) rather than leaking to a
# cloud provider. Still: this config schema has NOT been verified against an
# installed OpenCode on a PHI machine — VERIFY on the work box before any
# PHI-adjacent use (see Z-137):
#   1. `zopencode` reaches the local model (a prompt returns a response).
#   2. No cloud provider is contacted (`sudo bandwhich` shows loopback only).
#   3. Session sharing is OFF.
#
# Usage:
#   zopencode                 # launch OpenCode in the current repo (local model)
#   zopencode run "prompt"    # non-interactive (if supported by the installed CLI)

zdots_opencode_init() {
  # Gate + locality: mode check and endpoint locality together. Fail-closed.
  if ! typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1; then
    # shellcheck source=lib/ai_boundary.bash
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1 \
    && zdots_ai_gated_endpoint "zopencode" >/dev/null

  local _endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:11500}"

  # Generate a zdots-managed OpenCode config that points at the local endpoint
  # and disables sharing. Regenerated each run so it tracks the active endpoint.
  local _cfg_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zdots/opencode"
  [[ -d "$_cfg_dir" ]] || mkdir -p "$_cfg_dir" 2>/dev/null
  local _cfg="${_cfg_dir}/opencode.json"

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg base "${_endpoint}/v1" '{
      "$schema": "https://opencode.ai/config.json",
      "share": "disabled",
      "autoshare": false,
      "provider": {
        "zdots-local": {
          "npm": "@ai-sdk/openai-compatible",
          "name": "zdots local (llama.cpp)",
          "options": { "baseURL": $base, "apiKey": "local" },
          "models": { "local": { "name": "local (llama.cpp)" } }
        }
      },
      "model": "zdots-local/local"
    }' > "$_cfg" 2>/dev/null
  fi

  # OpenCode reads OPENCODE_CONFIG as the config file path.
  export OPENCODE_CONFIG="$_cfg"
  # Belt-and-suspenders: no telemetry/sharing from a PHI-adjacent machine.
  export OPENCODE_DISABLE_AUTOUPDATE="1"

  # One-time verification nudge (per machine), since the schema is unverified.
  local _stamp="${_cfg_dir}/.verified-local"
  if [[ ! -f "$_stamp" ]]; then
    printf 'zopencode: configured for the local endpoint (%s) with sharing disabled.\n' "${_endpoint}/v1" >&2
    printf 'zopencode: VERIFY local-only binding before any PHI use (Z-137):\n' >&2
    printf '  - a prompt returns a response from the local model\n' >&2
    printf '  - `sudo bandwhich` shows loopback only (no cloud egress)\n' >&2
    printf '  then: touch %s to silence this notice.\n' "$_stamp" >&2
  fi
}

# zopencode — launch OpenCode wired to local llama.cpp, from any directory.
zopencode() {
  zdots_opencode_init

  if ! command -v opencode >/dev/null 2>&1; then
    printf 'zopencode: opencode not installed — `brew install opencode` (it is in Brewfile.home/.work).\n' >&2
    return 127
  fi

  typeset -f zdots_trace_log >/dev/null 2>&1 && zdots_trace_log "ai_query" "tool=zopencode,args=$*"

  opencode "$@"
}
