#!/usr/bin/env bash
# lib/ai_boundary.bash — AI endpoint safety enforcement.
#
# Two controls used by every AI-touching tool:
#
#   zdots_ai_gate TOOL          exits 2 cleanly if ZDOTS_AI_MODE=none
#   zdots_assert_local_endpoint URL  hard-fails if ZDOTS_AI_MODE=local but
#                               endpoint is not loopback or RFC-1918
#
# Call zdots_ai_gate first, then zdots_assert_local_endpoint, before any
# network request to an AI endpoint. Source this file to load both functions.

_AI_BOUNDARY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/audit_log.bash
[[ -r "$_AI_BOUNDARY_DIR/audit_log.bash" ]] && source "$_AI_BOUNDARY_DIR/audit_log.bash"
unset _AI_BOUNDARY_DIR

# Exit cleanly when AI is disabled. No network attempt is made.
zdots_ai_gate() {
  local tool="${1:-ai}"
  local mode="${ZDOTS_AI_MODE:-local}"
  if [[ "$mode" == "none" ]]; then
    zdots_audit_log "ai_gate_triggered" "tool=$tool mode=$mode"
    printf '%s: AI unavailable (ZDOTS_AI_MODE=none)\n' "$tool" >&2
    printf '%s: to enable local AI: set ZDOTS_AI_MODE=local and run llama-ctl start\n' "$tool" >&2
    printf '%s: to enable cloud AI: set ZDOTS_AI_MODE=cloud in .zdots.local (requires .zdots.secrets)\n' "$tool" >&2
    exit 2
  fi
}

# Assert the AI endpoint is loopback or RFC-1918 when ZDOTS_AI_MODE=local.
# Exits 1 with a SECURITY-prefixed message if the assertion fails.
# cloud and none modes bypass this check.
zdots_assert_local_endpoint() {
  local endpoint="${1:-${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}}"
  local mode="${ZDOTS_AI_MODE:-local}"

  [[ "$mode" == "cloud" ]] && return 0
  [[ "$mode" == "none"  ]] && return 0

  # Strip scheme and path; isolate host
  local host
  host=$(printf '%s' "$endpoint" | sed 's|^[a-zA-Z][a-zA-Z0-9+.-]*://||; s|/.*||; s|:.*||; s|^\[||; s|\]$||')

  if [[ "$host" == "localhost" ]] ||
     [[ "$host" == "::1"       ]] ||
     [[ "$host" =~ ^127\.      ]] ||
     [[ "$host" =~ ^10\.       ]] ||
     [[ "$host" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] ||
     [[ "$host" =~ ^192\.168\. ]]; then
    zdots_audit_log "endpoint_assertion_pass" "endpoint=$endpoint mode=$mode"
    return 0
  fi

  zdots_audit_log "endpoint_assertion_fail" "endpoint=$endpoint mode=$mode"
  printf 'zdots: SECURITY: AI endpoint is not local: %s\n' "$endpoint" >&2
  printf 'zdots: ZDOTS_AI_MODE=local requires a loopback or RFC-1918 address.\n' >&2
  printf 'zdots: To allow a cloud endpoint, set ZDOTS_AI_MODE=cloud in .zdots.local.\n' >&2
  printf 'zdots: To disable AI entirely, set ZDOTS_AI_MODE=none.\n' >&2
  exit 1
}
