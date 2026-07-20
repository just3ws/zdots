---
id: Z-227
title: >-
  [agent-issue] AGENTS.md §5 shows zdots-issue --high but CLI only accepts
  --severity high
status: To Do
assignee: []
created_date: '2026-07-15 17:56'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 106895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** friction
**Severity:** low
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

AGENTS.md section 5 example block lists 'zdots-issue --high "This is blocking my current task"' but the command exits 2 with 'unknown option: --high'. Actual flag is --severity high. Either add the --high shorthand or fix the doc example.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
