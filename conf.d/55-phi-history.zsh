# conf.d/55-phi-history.zsh — PHI redaction hook for shell history.
# Loaded only in interactive shells. Skipped if ZDOTS_HISTORY_REDACT != 1.
#
# Behavior:
#   - Connection strings (postgresql://, mysql://, redis:// with credentials)
#     are SUPPRESSED entirely via zdots-phi-scrub --check — entry not written.
#   - All other patterns from etc/phi-patterns.yaml are REDACTED in-place
#     via zdots-phi-scrub (default mode). Single pass over compiled patterns.
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

  # Suppress-flagged patterns (connection strings): drop entry entirely.
  # zdots-phi-scrub --check: exit 0 = matches suppress, exit 1 = doesn't match.
  if echo "$line" | zdots-phi-scrub --check >/dev/null 2>&1; then
    elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
    ts_ms=$(( EPOCHREALTIME * 1000 ))
    _phi_history_maybe_record_overhead "suppressed" "$elapsed" "$threshold_ms" "$ts_ms"
    zdots_audit_log "history_suppressed" "reason=suppress_pattern"
    return 1
  fi

  # Redact remaining patterns via the Go binary (single pass over all patterns).
  local redacted
  redacted="$(echo "$line" | zdots-phi-scrub)"
  local scrub_status=$?
  elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
  ts_ms=$(( EPOCHREALTIME * 1000 ))

  if (( scrub_status != 0 )); then
    # zdots-phi-scrub failed (binary unavailable or unexpected suppress match).
    # Suppress the entry rather than risk writing sensitive data.
    _phi_history_maybe_record_overhead "scrub_failure" "$elapsed" "$threshold_ms" "$ts_ms"
    zdots_audit_log "history_suppressed" "reason=scrub_failure"
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
