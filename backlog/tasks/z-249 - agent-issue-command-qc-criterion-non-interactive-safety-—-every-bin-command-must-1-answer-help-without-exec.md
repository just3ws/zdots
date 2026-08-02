---
id: Z-249
title: >-
  [agent-issue] command-qc criterion: non-interactive safety — every bin command
  must (1) answer --help without exec
status: To Do
assignee: []
created_date: '2026-07-21 21:41'
updated_date: '2026-08-01 09:55'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 125895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `255372c5168f0e694bae41e7302a296d`

command-qc criterion: non-interactive safety — every bin command must (1) answer --help without executing its action (zdots-man-gen fork-bombed on one that didn't, work hit the same class 2026-07-10: 'work-daily-refresh-run --help launched the whole daily chain') and (2) never block on a TTY prompt when stdin is not a terminal (capture --yes class). Wire both into command-qc + a contract test.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit (45-command probe): 43/45 answer --help fast rc=0. Live violations: cc-home has NO arg parsing — '--help' becomes the prompt to a real CC launch (rc=124; a typo burns a cloud session, and it sits in docs_contract's --help list so the test hangs or passes vacuously); zdots-pulse ignores --help and runs probes. Smallest fix: one docs_contract.bats sweep — timeout 5 <cmd> --help </dev/null, rc=0 + usage-ish output, for every bin/ cmd not in known-gaps — plus -h/--help cases in the two offenders.
<!-- SECTION:NOTES:END -->
