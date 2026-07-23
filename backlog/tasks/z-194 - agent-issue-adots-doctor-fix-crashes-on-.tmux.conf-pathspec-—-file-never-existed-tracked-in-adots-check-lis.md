---
id: Z-194
title: >-
  [agent-issue] adots-doctor --fix crashes on '.tmux.conf' pathspec — file never
  existed/tracked in adots; check-lis
status: Done
assignee: []
created_date: '2026-07-02 01:11'
updated_date: '2026-07-23 02:31'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Re-tested 2026-07-22: adots-doctor --fix ran clean, exit 0, no crash on .tmux.conf pathspec. Not reproducible — closing.
<!-- SECTION:NOTES:END -->
