---
id: Z-364
title: >-
  [agent-issue] make check fails on the managed work Mac (2026-11-13, main
  462ce4f5) independent of any change: (1)
status: To Do
assignee: []
created_date: '2026-11-13T17:54:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 241895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7a084f400fe91d285e4b113951e052c5`

make check fails on the managed work Mac (2026-11-13, main 462ce4f5) independent of any change: (1) 'expected exactly one PNPM_HOME/bin PATH entry' because ~/.local/share/pnpm/bin did not exist (bin/bootstrap is skipped on managed machines; created by hand); (2) bats failures in adots_my_structure (prepare/migrate), bus_schedule (passengers, conversations), utilization_analytics, and docs_contract #3/#13 (zdots-endpoints --help rc=1). docs_contract fails identically on main.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
