# conf.d/55-phi-history.zsh — PHI redaction hook for shell history.
# Loaded only in interactive shells. Skipped if ZDOTS_HISTORY_REDACT != 1.
#
# Behavior:
#   - Connection strings (postgresql://, mysql://, redis:// with credentials)
#     are SUPPRESSED entirely via phi_should_suppress() — entry not written.
#   - All other patterns from etc/phi-patterns.yaml are REDACTED in-place
#     via phi_scrub(). Single sed pass over compiled patterns.
#   - If PHI protection is unavailable (yq absent), all commands are suppressed
#     until the system is correctly configured.
#
# Pattern source: etc/phi-patterns.yaml (PHI Pattern Registry). No patterns
# are defined in this file. To add a pattern, edit the registry.

[[ "${ZDOTS_HISTORY_REDACT:-1}" == "1" ]] || return 0

[[ -r "${ZDOTDIR}/lib/audit_log.bash" ]] && source "${ZDOTDIR}/lib/audit_log.bash"
[[ -r "${ZDOTDIR}/lib/shell_hook_metrics.bash" ]] && source "${ZDOTDIR}/lib/shell_hook_metrics.bash"

# Eagerly compile patterns at shell startup — not inside the hook.
# This is a fatal startup check: if patterns fail to compile, the shell cannot
# continue safely. All PHI protection depends on this initialization.
if [[ -r "${ZDOTDIR}/lib/phi_scrubber.bash" ]]; then
  source "${ZDOTDIR}/lib/phi_scrubber.bash"
  if ! phi_scrubber_init; then
    printf 'zdots: FATAL — PHI pattern compilation failed at startup.\n' >&2
    printf 'zdots: History redaction unavailable. Shell startup aborted.\n' >&2
    printf 'zdots: Fix: ensure yq is installed and %s/etc/phi-patterns.yaml is readable.\n' "${ZDOTDIR}" >&2
    exit 1
  fi
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
  if phi_should_suppress "$line"; then
    elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
    ts_ms=$(( EPOCHREALTIME * 1000 ))
    _phi_history_maybe_record_overhead "suppressed" "$elapsed" "$threshold_ms" "$ts_ms"
    zdots_audit_log "history_suppressed" "reason=suppress_pattern"
    return 1
  fi

  # Redact remaining patterns via compiled registry (single sed pass).
  local redacted
  redacted="$(phi_scrub <<< "$line")"
  local scrub_status=$?
  elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
  ts_ms=$(( EPOCHREALTIME * 1000 ))

  if (( scrub_status != 0 )); then
    # phi_scrub failed (patterns unavailable or unexpected suppress match).
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
