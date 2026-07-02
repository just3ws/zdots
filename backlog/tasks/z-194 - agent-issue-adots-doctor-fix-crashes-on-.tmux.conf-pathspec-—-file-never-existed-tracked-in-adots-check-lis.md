---
id: Z-194
title: >-
  [agent-issue] adots-doctor --fix crashes on '.tmux.conf' pathspec — file never
  existed/tracked in adots; check-lis
status: To Do
assignee: []
created_date: '2026-07-02 01:11'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 90890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `160b54f963f2498e1f715ff77df2388f`

adots-doctor --fix crashes on '.tmux.conf' pathspec — file never existed/tracked in adots; check-list in the script is stale. Colima legacy-root fix (--fix) works and is idempotent; only this trailing check fails.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
