# conf.d/55-phi-history.zsh — PHI redaction hook for shell history.
# Loaded only in interactive shells. Skipped if ZDOTS_HISTORY_REDACT != 1.
#
# Behavior:
#   - A single zdots-phi-scrub (default mode) invocation per command:
#       exit 0 → clean (or redacted, when stdout differs from input)
#       exit 2 → SUPPRESSED (connection string etc.) — entry not written
#       exit 1 → scrub failure — entry suppressed (fail safe)
#   - One process spawn per command (previously two: a redundant --check pre-pass
#     plus the redact pass). Default mode already detects suppress patterns.
#   - If the binary is unavailable, all commands are suppressed until corrected.
#
# Pattern source: etc/phi-patterns.yaml (PHI Pattern Registry). No patterns
# are defined in this file. To add a pattern, edit the registry.
#
# Binary: cmd/zdots-phi-scrub/ (canonical, RE2 engine, single source of truth)

[[ "${ZDOTS_HISTORY_REDACT:-1}" == "1" ]] || return 0

[[ -r "${ZDOTDIR}/lib/audit_log.bash" ]] && source "${ZDOTDIR}/lib/audit_log.bash"
[[ -r "${ZDOTDIR}/lib/shell_hook_metrics.bash" ]] && source "${ZDOTDIR}/lib/shell_hook_metrics.bash"

# Validate the binary is available at shell startup — fatal if not.
# This is a hard startup check: if the binary is missing, the shell cannot
# continue safely. All PHI protection depends on it.
if ! command -v zdots-phi-scrub >/dev/null 2>&1; then
  printf 'zdots: FATAL — zdots-phi-scrub binary not found in PATH.\n' >&2
  printf 'zdots: History redaction unavailable. Shell startup aborted.\n' >&2
  printf 'zdots: Fix: ensure zdots-phi-scrub is built and in PATH (bin/zdots-phi-scrub).\n' >&2
  exit 1
fi

# Pre-validate the registry at startup (not inside the hook).
if ! zdots-phi-scrub --init >/dev/null 2>&1; then
  printf 'zdots: FATAL — PHI pattern compilation failed at startup.\n' >&2
  printf 'zdots: History redaction unavailable. Shell startup aborted.\n' >&2
  printf 'zdots: Fix: ensure %s/etc/phi-patterns.yaml is readable and valid.\n' "${ZDOTDIR}" >&2
  exit 1
fi

_phi_history_maybe_record_overhead() {
  local metric_status="$1"
  local elapsed="$2"
  local threshold_ms="$3"
  local ts_ms="$4"

  (( elapsed > threshold_ms )) || return 0
  shell_hook_metrics_record "phi-history" "$metric_status" "$elapsed" "$threshold_ms" "$ts_ms"
}

zshaddhistory() {
  local line="${1%%$'\n'}"
  local t0=$EPOCHREALTIME
  local threshold_ms=1 print_threshold_ms=20 elapsed ts_ms

  # Single pass: default mode redacts and also detects suppress patterns.
  #   exit 0 → clean/redacted (stdout holds the result)
  #   exit 2 → suppress-flagged pattern (connection string) — drop entry
  #   exit 1 → scrub failure — drop entry (fail safe)
  local redacted
  redacted="$(echo "$line" | zdots-phi-scrub 2>/dev/null)"
  local scrub_status=$?

  if (( scrub_status != 0 && scrub_status != 2 )); then
    # Z-266: operational failure (not a suppress-match). The dominant cause is
    # a transient registry read (~6ms exit-1 while git rewrites
    # phi-patterns.yaml), which self-heals — retry once, keeping stderr this
    # time so the audit trail names the error instead of a bare
    # reason=scrub_failure. Cold path only: 188 events in 2.5 months.
    local _scrub_errf="${TMPDIR:-/tmp}/.zdots-phi-err.$$" _scrub_err=""
    redacted="$(echo "$line" | zdots-phi-scrub 2>"$_scrub_errf")"
    scrub_status=$?
    [[ -s "$_scrub_errf" ]] && _scrub_err="$(tr '\n' ' ' <"$_scrub_errf" | head -c 200)"
    rm -f -- "$_scrub_errf"
  fi

  elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
  ts_ms=$(( EPOCHREALTIME * 1000 ))

  if (( scrub_status == 2 )); then
    # Deliberate suppress-match: drop the entry entirely.
    _phi_history_maybe_record_overhead "suppressed" "$elapsed" "$threshold_ms" "$ts_ms"
    zdots_audit_log "history_suppressed" "reason=suppress_pattern"
    return 1
  fi

  if (( scrub_status != 0 )); then
    # zdots-phi-scrub failed twice (registry/stdin error). Suppress the entry
    # rather than risk writing sensitive data. The detail carries the
    # scrubber's own stderr (error text only — the Go binary never echoes
    # input), so the audit trail names the cause (Z-266).
    _phi_history_maybe_record_overhead "scrub_failure" "$elapsed" "$threshold_ms" "$ts_ms"
    zdots_audit_log "history_suppressed" "reason=scrub_failure rc=${scrub_status} detail=${_scrub_err:-empty-stderr}"
    return 1
  fi

  if [[ "$redacted" != "$line" ]]; then
    _phi_history_maybe_record_overhead "redacted" "$elapsed" "$threshold_ms" "$ts_ms"
    zdots_audit_log "history_redacted" "reason=phi_pattern"
    print -s -- "$redacted"
    return 1
  fi

  # Performance guard — warn if hook exceeded 1ms on a clean command
  _phi_history_maybe_record_overhead "clean" "$elapsed" "$threshold_ms" "$ts_ms"
  (( elapsed > print_threshold_ms )) && print -u2 "zdots: phi-history: ${elapsed}ms overhead (threshold ${print_threshold_ms}ms)" || true

  return 0
}
