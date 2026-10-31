---
id: Z-355
title: '[agent-issue] zsvc health marks optional stopped services unhealthy'
status: To Do
assignee: []
created_date: '2026-10-31T23:15:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 226895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `5175011939a1195d366748987d19123f`

I was checking the normal bare-metal service posture with Colima intentionally stopped and the optional bus-coordinator parked. `zsvc health --json` returned healthy=false because colima (stopped) and coordinator (not-registered) both had health=fail, even though all required platform services and the six core local URLs reported ok, and `capabilities --json` reports health_errors=0. Expected: optional/on-demand services should be reported distinctly and should not make the required-platform health summary false. Please add an explicit required/optional policy and focused coverage for the summary semantics.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
