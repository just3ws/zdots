#!/usr/bin/env bash
# lib/ai_boundary.bash — AI endpoint safety enforcement.
#
# Functional pipeline: _check variants are canonical predicates (return-based,
# ZLE-safe, composable with &&). Exit variants are adapters that call the
# predicate and add effects (messages + exit) only on failure.
#
# Predicates — compose with &&, safe everywhere including ZLE callbacks:
#   zdots_ai_gate_check TOOL              returns 1 if ZDOTS_AI_MODE=none
#   zdots_assert_local_endpoint_check URL returns 1 if local-mode endpoint is non-local
#   zdots_ai_gated_endpoint_check TOOL    both checks in one call (ZLE convenience)
#
# Adapters — for scripts and bin/ tools where exit is safe:
#   zdots_ai_gate TOOL               exits 2 with messages if gate check fails
#   zdots_assert_local_endpoint URL  exits 1 with messages if endpoint check fails
#   zdots_ai_gated_endpoint TOOL     both adapters + echoes the endpoint

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
# Predicates — canonical implementations, hold all logic and audit calls
# ---------------------------------------------------------------------------

zdots_ai_gate_check() {
  local tool="${1:-ai}"
  local mode="${ZDOTS_AI_MODE:-local}"
  if [[ "$mode" == "none" ]]; then
    zdots_audit_log "ai_gate_triggered" "tool=$tool mode=$mode"
    return 1
  fi
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

# Combined predicate for ZLE widgets — gate + locality in one call.
zdots_ai_gated_endpoint_check() {
  local tool="${1:-ai}"
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"
  zdots_ai_gate_check "$tool" && zdots_assert_local_endpoint_check "$endpoint"
}

# ---------------------------------------------------------------------------
# Adapters — call the predicate; on failure, emit messages and exit
# ---------------------------------------------------------------------------

zdots_ai_gate() {
  local tool="${1:-ai}"
  if ! zdots_ai_gate_check "$tool"; then
    printf '%s: AI unavailable (ZDOTS_AI_MODE=none)\n' "$tool" >&2
    printf '%s: to enable local AI: set ZDOTS_AI_MODE=local and run llama-ctl start\n' "$tool" >&2
    printf '%s: to enable cloud AI: set ZDOTS_AI_MODE=cloud in .zdots.local\n' "$tool" >&2
    exit 2
  fi
}

zdots_assert_local_endpoint() {
  local endpoint="${1:-${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}}"
  if ! zdots_assert_local_endpoint_check "$endpoint"; then
    printf 'zdots: SECURITY: AI endpoint is not local: %s\n' "$endpoint" >&2
    printf 'zdots: ZDOTS_AI_MODE=local requires a loopback or RFC-1918 address.\n' >&2
    printf 'zdots: To allow a cloud endpoint, set ZDOTS_AI_MODE=cloud in .zdots.local.\n' >&2
    printf 'zdots: To disable AI entirely, set ZDOTS_AI_MODE=none.\n' >&2
    exit 1
  fi
}

# Combines gate + assertion + echoes the endpoint. Use as:
#   endpoint=$(zdots_ai_gated_endpoint "tool") — gate and endpoint in one operation.
zdots_ai_gated_endpoint() {
  local tool="${1:-ai}"
  zdots_ai_gate "$tool"
  local endpoint="${ZDOTS_AI_ENDPOINT:-http://127.0.0.1:8080}"
  zdots_assert_local_endpoint "$endpoint"
  printf '%s' "$endpoint"
}
