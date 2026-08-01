---
id: Z-245
title: >-
  [agent-issue] Backlog ID allocation races across machines: both machines
  assign the next sequential Z-nnn independ
status: To Do
assignee: []
created_date: '2026-07-21 16:52'
updated_date: '2026-08-01 09:55'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 121895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `262025207aeb723c5f1b68236fc119cd`

Backlog ID allocation races across machines: both machines assign the next sequential Z-nnn independently, so concurrent filings collide (Z-235/Z-236 collided 2026-07-20, Z-240 again 2026-07-21 — work-machine tasks renumbered to Z-240/241→Z-244 twice). Suggest per-machine ID ranges, a machine suffix, or allocating IDs at push/merge time.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit: partial mitigation landed — zdots-platform idscan (1014247bb) detects collisions at integrate time. Remaining scope: prevent the race at allocation (per-machine ranges, machine suffix, or merge-time ID assignment).
<!-- SECTION:NOTES:END -->
