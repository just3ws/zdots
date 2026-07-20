---
id: Z-229
title: >-
  [agent-issue] zdots-worker job failures invisible to OpenObserve — session
  brief reported 'clean' during a failure storm
status: To Do
assignee: []
created_date: '2026-07-15 18:32'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 108895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

This morning's session brief said 'runtime (last 6h, OpenObserve): clean — 0 error logs, 0 failed spans' while zdots-worker.log recorded a continuous stream of docs_sync FAILED (inference_error Net::ReadTimeout) events. o2_logs grep README over 8h returns zero rows. The worker's launchd stdout log is not reaching the collector, so the Observable Control Plane is blind to its highest-churn background failure mode. Expected: worker job start/success/failure emitted as spans or logs to the local collector so o2_failures surfaces them.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
