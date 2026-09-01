---
id: Z-323
title: '[agent-issue] zdots-ctl up blocked by trace log permission'
status: Done
assignee: []
created_date: '2026-08-25 18:36'
updated_date: '2026-09-01 13:07'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 198895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `0d373b935b864924005c56267f765407`

zdots-ctl up cannot bring the Platform Services up because lib/trace_log.bash cannot append to /Users/mike/.local/state/zsh/traces.jsonl: Operation not permitted. PostgreSQL and the communication Bus remain unavailable, blocking Bus verification and focused integration tests.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: lib/trace_log.bash did `printf ... >> $trace_file` with no error handling. bin/zdots-ctl runs `set -euo pipefail` and calls zdots_trace_log 'platform_up' 'start' at line 112, early in `up`. When the append hit EPERM (root-owned traces.jsonl from a prior sudo-context write), the function returned non-zero and set -e aborted `zdots-ctl up` before PostgreSQL/Bus started — exactly the reported symptom. Fix: append `2>/dev/null || return 0` to the write — instrumentation must never abort a caller. Added tests/trace_log.bats (3 cases) incl. the set -e regression. Blink-tested: green->red(revert)->green. Full phi_boundary suite (59) still green. traces.jsonl currently mike:staff 0600, appends fine; the EPERM condition no longer present either way.
<!-- SECTION:NOTES:END -->
