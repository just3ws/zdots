---
id: Z-360
title: >-
  [agent-issue] Knowledge Layer hydration lacks agent-session database
  authentication
status: To Do
assignee: []
created_date: '2026-11-06T22:26:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: low
ordinal: 231895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** low
**Trace ID:** `1de609fd72b17f79643e48967c7100f6`

During the 2026-11-06 work-profile readiness review, zdots-ctx hydrate tooling-catalog exited 1 with PostgreSQL fe_sendauth: no password supplied. Expected a compact tooling catalog. Continued using repository sources; did not inspect credentials or change database authentication. Recheck from an authenticated operator Terminal before diagnosing host health.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
