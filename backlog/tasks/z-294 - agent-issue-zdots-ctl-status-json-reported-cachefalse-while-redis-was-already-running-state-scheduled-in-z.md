---
id: Z-294
title: >-
  [agent-issue] zdots-ctl status --json reported cache=false while redis was
  already running (state 'scheduled' in z
status: To Do
assignee: []
created_date: '2026-08-04 23:17'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 169895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `0ee377bd4f0c542e1a7107e4121460b1`

zdots-ctl status --json reported cache=false while redis was already running (state 'scheduled' in zsvc list) — on-demand launchd semantics read as down; caused false pre-flight FAIL in /zdots-update P0-B on 2026-08-04

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
