---
id: Z-249
title: >-
  [agent-issue] command-qc criterion: non-interactive safety — every bin command
  must (1) answer --help without exec
status: To Do
assignee: []
created_date: '2026-07-21 21:41'
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
