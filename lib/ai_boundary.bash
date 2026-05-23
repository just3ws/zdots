#!/usr/bin/env bash
# lib/ai_boundary.bash — AI endpoint safety enforcement.
#
# Four controls — exit-based (scripts) and return-based (ZLE/callbacks):
#
#   zdots_ai_gate TOOL               exits 2 cleanly if ZDOTS_AI_MODE=none
#   zdots_assert_local_endpoint URL  exits 1 if local-mode endpoint is non-local
#   zdots_ai_gate_check TOOL         same as zdots_ai_gate but returns 1 (ZLE-safe)
#   zdots_assert_local_endpoint_check URL  same but returns 1 (ZLE-safe)
#   zdots_ai_gated_endpoint TOOL     runs both exit-based checks, then echoes endpoint
#
# Scripts: call zdots_ai_gated_endpoint — gate and endpoint in one operation.
# ZLE widgets: call zdots_ai_gate_check + zdots_assert_local_endpoint_check + return.

# shellcheck source=lib/audit_log.bash
[[ -r "${ZDOTDIR}/lib/audit_log.bash" ]] && source "${ZDOTDIR}/lib/audit_log.bash"

# ---------------------------------------------------------------------------
# _zdots_is_local_endpoint URL — returns 0 if host is loopback or RFC-1918
# ---------------------------------------------------------------------------
_zdots_is_local_endpoint() {
  local host
  host=$(printf '%s' "${1:-}" | sed 's|^[a-zA-Z][a-zA-Z0-9+.-]*://||; s|/.*||; s|:.*||; s|^\[||; s|\]$||')
  [[ "$host" == "localhost" ]] ||
  [[ "$host" == "::1"       ]] ||
  [[ "$host" =~ ^127\.      ]] ||
  [[ "$host" =~ ^10\.       ]] ||
  [[ "$host" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] ||
  [[ "$host" =~ ^192\.168\. ]]
}

# ---------------------------------------------------------------------------
# Exit-based variants — for scripts and bin/ tools (safe to call exit)
# ---------------------------------------------------------------------------

zdots_ai_gate() {
  local tool="${1:-ai}"
  local mode="${ZDOTS_AI_MODE:-local}"
  if [[ "$mode" == "none" ]]; then
    zdots_audit_log "ai_gate_triggered" "tool=$tool mode=$mode"
    printf '%s: AI unavailable (ZDOTS_AI_MODE=none)\n' "$tool" >&2
    printf '%s: to enable local AI: set ZDOTS_AI_MODE=local and run llama-ctl start\n' "$tool" >&2
    printf '%s: to enable cloud AI: set ZDOTS_AI_MODE=cloud in .zdots.local\n' "$tool" >&2
    exit 2
  fi
}

zdots_assert_local_endpoint() {
  local endpoint="${1:-${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}}"
  local mode="${ZDOTS_AI_MODE:-local}"
  [[ "$mode" == "cloud" ]] && return 0
  [[ "$mode" == "none"  ]] && return 0
  if _zdots_is_local_endpoint "$endpoint"; then
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

# Combines mode gate + locality assertion + echoes the endpoint.
# Use as: endpoint=$(zdots_ai_gated_endpoint "tool") — getting the endpoint
# and passing the gate are the same operation.
zdots_ai_gated_endpoint() {
  local tool="${1:-ai}"
  zdots_ai_gate "$tool"
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"
  zdots_assert_local_endpoint "$endpoint"
  printf '%s' "$endpoint"
}

# ---------------------------------------------------------------------------
# Return-based variants — for ZLE widgets and callbacks (must not call exit)
# ---------------------------------------------------------------------------

zdots_ai_gate_check() {
  local tool="${1:-ai}"
  local mode="${ZDOTS_AI_MODE:-local}"
  if [[ "$mode" == "none" ]]; then
    zdots_audit_log "ai_gate_triggered" "tool=$tool mode=$mode"
    return 1
  fi
  return 0
}

zdots_assert_local_endpoint_check() {
  local endpoint="${1:-${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}}"
  local mode="${ZDOTS_AI_MODE:-local}"
  [[ "$mode" == "cloud" ]] && return 0
  [[ "$mode" == "none"  ]] && return 0
  if _zdots_is_local_endpoint "$endpoint"; then
    zdots_audit_log "endpoint_assertion_pass" "endpoint=$endpoint mode=$mode"
    return 0
  fi
  zdots_audit_log "endpoint_assertion_fail" "endpoint=$endpoint mode=$mode"
  return 1
}
