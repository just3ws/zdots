# conf.d/55-phi-history.zsh — PHI redaction hook for shell history.
# Loaded only in interactive shells. Skipped if ZDOTS_HISTORY_REDACT != 1.
#
# Behavior:
#   - Connection strings (postgresql://, mysql://, redis:// with credentials)
#     are SUPPRESSED entirely — the entry is not written to history.
#   - SSN, MRN, DOB patterns are REDACTED in-place with [REDACTED-*] markers.
#   - Site-specific patterns in ZDOTS_HISTORY_REDACT_PATTERNS are also redacted.
#   - Adds <1ms overhead on clean commands (Zsh built-in =~ only).
#   - Warns to stderr if overhead exceeds 1ms.

[[ "${ZDOTS_HISTORY_REDACT:-1}" == "1" ]] || return 0

zshaddhistory() {
  local line="${1%%$'\n'}"
  local t0=$EPOCHREALTIME

  # Suppress connection strings with credentials entirely — no redaction attempt,
  # the entry must not appear in history at all.
  if [[ "$line" =~ '(postgresql|mysql|redis)://[^@[:space:]]+@' ]]; then
    return 1
  fi

  local changed=0

  # SSN: NNN-NN-NNNN — Zsh built-in substitution, no fork
  if [[ "$line" =~ '[0-9]{3}-[0-9]{2}-[0-9]{4}' ]]; then
    # Zsh glob approximation (no quantifiers): cover the fixed-length pattern
    line="${line//[0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]/[REDACTED-SSN]}"
    changed=1
  fi

  # MRN / DOB — require sed for variable-length whitespace and digit runs
  if [[ "$line" =~ 'MRN[[:space:]]*:?[[:space:]]*[0-9]' ]]; then
    line=$(printf '%s' "$line" | command sed -E 's/MRN[[:space:]]*:?[[:space:]]*[0-9]+/[REDACTED-MRN]/g')
    changed=1
  fi

  if [[ "$line" =~ 'DOB[[:space:]]*:?[[:space:]]*[0-9]' ]]; then
    line=$(printf '%s' "$line" | command sed -E 's/DOB[[:space:]]*:?[[:space:]]*[0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}/[REDACTED-DOB]/g')
    changed=1
  fi

  # Site-specific patterns from .zdots.local — applied only when set
  if (( ${#ZDOTS_HISTORY_REDACT_PATTERNS[@]} > 0 )); then
    local p
    for p in "${ZDOTS_HISTORY_REDACT_PATTERNS[@]}"; do
      if [[ "$line" =~ "$p" ]]; then
        line=$(printf '%s' "$line" | command sed -E "s/${p}/[REDACTED]/g")
        changed=1
      fi
    done
  fi

  if (( changed )); then
    print -s -- "$line"
    return 1
  fi

  # Performance guard — warn if hook exceeded 1ms on a clean command
  local elapsed=$(( (EPOCHREALTIME - t0) * 1000 ))
  (( elapsed > 1 )) && print -u2 "zdots: phi-history: ${elapsed}ms overhead (threshold 1ms)" || true

  return 0
}
