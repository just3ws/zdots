---
id: Z-371
title: '[agent-issue] make check fails on publisher and coverage gates'
status: To Do
assignee: []
created_date: '2026-11-22T23:55:58Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 248895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `607f6da65ee7180a79d24a7038c917c5`

During documentation task Z-370, make check failed. Captured output is /private/tmp/zdots-z370-check.log. Parallel suites report eight tests failing because bin/zdots-pages is missing (exit 127), RBS coverage 13.85% below the 14.06% floor, and YARD coverage 41.98% below the 43.26% floor. make docs-contract passed all 16 tests; all eight affected Mermaid diagrams rendered. No runtime or library code was changed. Record these validation failures for a separately scoped review; do not repair infrastructure as part of Z-370.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
