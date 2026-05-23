#!/usr/bin/env bash
# lib/phi_scrubber.bash — PHI pattern scrubber for the zdots content pipeline.
#
# phi_scrub — reads from stdin, writes scrubbed content to stdout.
#             Returns 0 if content was clean, 1 if anything was redacted.
#
# Redaction markers (from PHI safety policy doc-002):
#   [REDACTED-SSN]   NNN-NN-NNNN
#   [REDACTED-MRN]   MRN: NNNNNN  /  MRN NNNNNN
#   [REDACTED-DOB]   DOB: MM/DD/YYYY  /  Date of Birth: ...
#   [REDACTED-CONN]  postgresql|mysql|redis connection strings with credentials

phi_scrub() {
  local input
  input=$(cat)

  local scrubbed
  scrubbed=$(printf '%s' "$input" | sed -E \
    -e 's/[0-9]{3}-[0-9]{2}-[0-9]{4}/[REDACTED-SSN]/g' \
    -e 's/MRN[[:space:]]*:?[[:space:]]*[0-9]+/[REDACTED-MRN]/g' \
    -e 's/(DOB|[Dd]ate[[:space:]]+[Oo]f[[:space:]]+[Bb]irth)[[:space:]]*:?[[:space:]]*[0-9]{1,2}[/\-][0-9]{1,2}[/\-][0-9]{2,4}/[REDACTED-DOB]/g' \
    -e 's;(postgresql|mysql|redis)://[^@[:space:]]+@[^/[:space:]]*;[REDACTED-CONN];g')

  printf '%s' "$scrubbed"

  # Return 1 (truthy "something changed") when redaction occurred
  [[ "$scrubbed" != "$input" ]]
}
