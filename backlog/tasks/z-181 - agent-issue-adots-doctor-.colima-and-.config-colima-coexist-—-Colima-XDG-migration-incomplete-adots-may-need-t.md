---
id: Z-181
title: >-
  [agent-issue] adots-doctor: .colima and .config/colima coexist — Colima XDG
  migration incomplete; adots may need t
status: Done
assignee: []
created_date: '2026-06-29 16:54'
updated_date: '2026-07-04 14:57'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 77890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `0d2e75b812e72d620a684e07675a75c9`

adots-doctor: .colima and .config/colima coexist — Colima XDG migration incomplete; adots may need to drop ~/.colima symlink/dir tracking once Colima is fully on XDG path

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Superseded by Z-195 resolution 2026-07-04: no XDG migration planned. ~/.colima stays canonical permanently; adots does not need to drop tracking since it was never zdots' concern — the symlink adots-doctor created is removed.
<!-- SECTION:NOTES:END -->
