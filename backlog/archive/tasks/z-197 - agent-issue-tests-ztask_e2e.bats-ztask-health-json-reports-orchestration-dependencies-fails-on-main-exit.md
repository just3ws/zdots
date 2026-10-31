---
id: Z-197
title: >-
  [agent-issue] tests/ztask_e2e.bats 'ztask health --json reports orchestration
  dependencies' fails on main (exit !=
status: Done
assignee: []
created_date: '2026-07-02 23:05'
updated_date: '2026-08-01 09:55'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 93890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `160b54f963f2498e1f715ff77df2388f`

tests/ztask_e2e.bats 'ztask health --json reports orchestration dependencies' fails on main (exit != 0). Reproduces on clean HEAD 58bf2e6 — likely landed with the 24f777b work-session patch (backlog cleanup / CLI hardening touched ztask surface). Unrelated to peer-bootstrap work.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit: No longer reproduces — bats tests/ztask_e2e.bats --filter 'orchestration dependencies' → ok 1 (re-verified this session); ztask health --json exits 0. Referenced SHAs predate the 2026-07-31 tenant-scrub rewrite.
<!-- SECTION:NOTES:END -->
