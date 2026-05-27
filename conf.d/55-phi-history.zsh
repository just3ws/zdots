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

# Eagerly compile patterns at shell startup — not inside the hook.
if [[ -r "${ZDOTDIR}/lib/phi_scrubber.bash" ]]; then
  source "${ZDOTDIR}/lib/phi_scrubber.bash"
  if ! phi_scrubber_init; then
    printf 'zdots: phi-history: PHI protection unavailable — all history suppressed until fixed\n' >&2
  fi
fi

zshaddhistory() {
  local line="${1%%$'\n'}"
  local t0=$EPOCHREALTIME

  # Suppress-flagged patterns (connection strings): drop entry entirely.
  if phi_should_suppress "$line"; then
    zdots_audit_log "history_suppressed" "reason=suppress_pattern"
    return 1
  fi

  # Redact remaining patterns via compiled registry (single sed pass).
  local redacted
  redacted="$(phi_scrub <<< "$line")"
  local scrub_status=$?

  if (( scrub_status != 0 )); then
    # phi_scrub failed (patterns unavailable or unexpected suppress match).
    # Suppress the entry rather than risk writing sensitive data.
    zdots_audit_log "history_suppressed" "reason=scrub_failure"
    return 1
  fi

  if [[ "$redacted" != "$line" ]]; then
    zdots_audit_log "history_redacted" "reason=phi_pattern"
    print -s -- "$redacted"
    return 1
  fi

  # Performance guard — warn if hook exceeded 1ms on a clean command
  local elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
  (( elapsed > 1 )) && print -u2 "zdots: phi-history: ${elapsed}ms overhead (threshold 1ms)" || true

  return 0
}
