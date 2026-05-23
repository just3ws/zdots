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
# Events emitted by the zdots toolchain:
#   ai_gate_triggered          ZDOTS_AI_MODE=none blocked an inference call
#   endpoint_assertion_pass    Locality check passed for an endpoint
#   endpoint_assertion_fail    Non-local endpoint blocked in local mode
#   capture_blocked            zdots-ctx capture suppressed (ZDOTS_CAPTURE_ENABLED=0)
#   capture_invoked            zdots-ctx capture ran (content scrubbed before write)
#   history_redacted           zshaddhistory hook redacted a command
#   boundary_violation         Any PHI boundary enforcement event

zdots_audit_log() {
  # No-op on non-darwin — unified logging is macOS-only
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0

  local event="${1:-unknown}"
  shift
  local detail="${*}"

  # log(1) is always available on macOS; subsystem/category land in the
  # unified log store readable by Console.app, MDM tools, and log(1).
  /usr/bin/log log \
    --subsystem "com.zdots" \
    --category  "phi-boundary" \
    -- "event=${event} ${detail}" 2>/dev/null || true
}
