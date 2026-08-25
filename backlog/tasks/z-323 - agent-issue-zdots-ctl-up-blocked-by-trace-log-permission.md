---
id: Z-323
title: '[agent-issue] zdots-ctl up blocked by trace log permission'
status: To Do
assignee: []
created_date: '2026-08-25 18:36'
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
