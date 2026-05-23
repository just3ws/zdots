#!/usr/bin/env bash
# lib/audit_log.bash — PHI-adjacent operation audit logging.
#
# Writes structured entries to macOS Unified Logging on darwin.
# No-ops silently on non-darwin systems.
#
# Usage:
#   zdots_audit_log <event> [detail...]
#
# Subsystem: com.zdots   Category: phi-boundary
#
# Query: log show --predicate 'subsystem == "com.zdots"' --last 1h
# Stream: log stream --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"'
#
# Events and their log types:
#   ai_gate_triggered          fault  — ZDOTS_AI_MODE=none blocked an inference call
#   endpoint_assertion_fail    fault  — Non-local endpoint blocked in local mode
#   boundary_violation         fault  — Any PHI boundary enforcement event
#   capture_blocked            default — zdots-ctx capture suppressed (ZDOTS_CAPTURE_ENABLED=0)
#   capture_invoked            default — zdots-ctx capture ran (content scrubbed before write)
#   endpoint_assertion_pass    info   — Locality check passed for an endpoint
#   history_redacted           info   — zshaddhistory hook redacted a command

zdots_audit_log() {
  # No-op on non-darwin — unified logging is macOS-only
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0

  local event="${1:-unknown}"
  shift
  local detail="${*}"

  # Map event names to log types — fault for blocks/violations, info for passes
  local type="default"
  case "$event" in
    *_fail|*_triggered|*_violation) type="fault"   ;;
    *_pass|*_redacted)              type="info"    ;;
  esac

  # --public ensures the message is readable in log show/stream without
  # private-data redaction. We write only event metadata, never PHI.
  /usr/bin/log emit \
    --subsystem "com.zdots" \
    --category  "phi-boundary" \
    --type      "$type" \
    --public \
    "event=${event} ${detail}" 2>/dev/null || true
}
