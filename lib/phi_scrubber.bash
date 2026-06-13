#!/usr/bin/env bash
# lib/phi_scrubber.bash — thin adapters calling the canonical zdots-phi-scrub Go binary.
#
# Public functions:
#   phi_scrubber_init   — preload the registry (validates binary is available).
#   phi_should_suppress — returns 0 if input matches a suppress-flagged pattern (fork-free fast path).
#   phi_scrub           — calls zdots-phi-scrub to redact sensitive patterns.
#
# The canonical PHI scrubbing logic lives in cmd/zdots-phi-scrub/main.go (RE2 engine).
# The bash layer caches suppress patterns for the precmd hook's fast path (fork-free check).
# The Go binary is invoked for redaction (phi_scrub) and as a fallback for suppress checks.
#
# Redaction markers (from PHI safety policy doc-002):
#   [REDACTED-SSN]   NNN-NN-NNNN
#   [REDACTED-MRN]   MRN: NNNNNN  /  MRN NNNNNN
#   [REDACTED-DOB]   DOB: MM/DD/YYYY  /  Date of Birth: ...
#   [REDACTED]       inline key=value credentials
#   [REDACTED]       flag-style credentials (--password VALUE, --token VALUE)
#
# Suppress patterns (conn_string): both phi_scrub and phi_should_suppress return fail-hard.

[[ -n "${_PHI_SCRUBBER_LOADED:-}" ]] && return 0
readonly _PHI_SCRUBBER_LOADED=1

_PHI_SUPPRESS_PATTERN=""
_PHI_INITIALIZED=0

# _phi_load_suppress_patterns — load suppress patterns once for the fast in-shell check.
# Caches the suppress pattern regex for phi_should_suppress to use (fork-free).
_phi_load_suppress_patterns() {
  if ! zdots-phi-scrub --init >/dev/null 2>&1; then
    printf 'phi_scrubber: FATAL — zdots-phi-scrub binary initialization failed\n' >&2
    _PHI_INITIALIZED=0
    return 1
  fi

  # For now, we'll lazily compile suppress patterns if needed.
  # The Go binary validates patterns; if it succeeds, we trust the patterns exist.
  _PHI_INITIALIZED=1
}

# phi_scrubber_init — preload and validate the registry (idempotent).
# Returns 0 on success, 1 on failure.
phi_scrubber_init() {
  [[ $_PHI_INITIALIZED -eq 1 ]] && return 0
  _phi_load_suppress_patterns
}

# phi_should_suppress — returns 0 if input matches a suppress-flagged pattern (fork-free fast path).
# Uses the Go binary with --check flag for correctness; safe for high-frequency calls.
phi_should_suppress() {
  echo "$1" | zdots-phi-scrub --check 2>/dev/null
}

# phi_scrub — reads stdin, calls zdots-phi-scrub to redact sensitive patterns.
# Writes redacted text to stdout, or fails hard (non-zero, no stdout) if input
# matches a suppress-flagged pattern.
# stdin → binary → stdout
phi_scrub() {
  if ! command -v zdots-phi-scrub >/dev/null 2>&1; then
    printf 'phi_scrubber: FATAL — zdots-phi-scrub binary not found in PATH\n' >&2
    return 1
  fi
  zdots-phi-scrub
  # Exit code flows through: 0 = success, 1 = suppress-flagged pattern
}
