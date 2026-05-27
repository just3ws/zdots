#!/usr/bin/env bash
# lib/message_hygiene.bash — Message Hygiene Pipeline.
#
# zdots_message_hygiene — reads from stdin, writes clean text to stdout.
#
# Pipeline (always runs in full, in order):
#   1. normalize  — strip null bytes, ANSI escapes, CRLF, C0 control chars.
#   2. phi_scrub  — redact SSN, MRN, DOB, credentials; fail-hard on conn strings.
#
# Normalize runs first: format artifacts can prevent PHI patterns from matching.
#
# Fails hard (non-zero) if PHI protection is unavailable (yq absent, registry
# missing) or if input contains a suppress-flagged pattern (connection strings).
# Callers must treat non-zero exit as a hard failure — do not continue.
#
# Callers: source this file. Do not source lib/phi_scrubber.bash directly.

[[ -n "${_MH_LIB_LOADED:-}" ]] && return 0
readonly _MH_LIB_LOADED=1

_MH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# shellcheck source=lib/phi_scrubber.bash
[[ -r "${_MH_LIB_DIR}/phi_scrubber.bash" ]] && source "${_MH_LIB_DIR}/phi_scrubber.bash"
unset _MH_LIB_DIR

# ---------------------------------------------------------------------------
# _mh_normalize — strip format artifacts from stdin. Private.
# ---------------------------------------------------------------------------
_mh_normalize() {
  if command -v perl >/dev/null 2>&1; then
    perl -pe '
      s/\x00//g;
      s/\r\n/\n/g; s/\r/\n/g;
      s/\e\[[0-9;?!>]*[A-Za-z]//g;
      s/\e\][^\a\e]*\a//g;
      s/\e\][^\e]*\e\\//g;
      s/\e[A-Za-z]//g;
      tr/\x01-\x08\x0b-\x0c\x0e-\x1f\x7f//d;
    '
  else
    LC_ALL=C tr -d '\0' \
      | LC_ALL=C tr -d '\r' \
      | sed $'s/\033\\[[0-9;?!>]*[A-Za-z]//g' \
      | sed $'s/\033][^\a]*\a//g' \
      | sed $'s/\033[A-Za-z]//g' \
      | LC_ALL=C tr -d \
          '\001\002\003\004\005\006\007\010\013\014\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177'
  fi
}

# ---------------------------------------------------------------------------
# zdots_message_hygiene — full hygiene pipeline, stdin → stdout.
# ---------------------------------------------------------------------------
zdots_message_hygiene() {
  _mh_normalize | phi_scrub
}
