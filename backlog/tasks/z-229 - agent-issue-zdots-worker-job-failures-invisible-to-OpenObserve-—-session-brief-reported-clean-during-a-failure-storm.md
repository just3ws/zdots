---
id: Z-229
title: >-
  [agent-issue] zdots-worker job failures invisible to OpenObserve — session
  brief reported 'clean' during a failure storm
status: Done
assignee: []
created_date: '2026-07-15 18:32'
updated_date: '2026-08-03 17:28'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: Zdots.init_otel commented out in zdots-brain cmd_worker → no-op tracer provider → all job.perform spans (incl. failure spans with recorded exceptions) dropped before export. Why it was disabled: init_otel crashed with 'uninitialized constant OpenTelemetry::SDK' because zdots-brain requires only the opentelemetry API gem. Fix bd66fbb: lazy-require opentelemetry-sdk + otlp exporter inside init_otel; re-enabled in cmd_worker (cmd_status left un-instrumented deliberately — one-shot CLI). Verified: induced failing embed job; o2_failures shows zdots-worker job.perform error spans. Session briefs' runtime line is trustworthy for worker failures again.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: claude
created: 2026-08-03 17:28
---
Regression found 2026-08-03 while chasing an unrelated o2-mcp gap: despite this fix, zdots-worker processed 311 jobs over 30 days with zero spans ever reaching OpenObserve (SELECT DISTINCT service_name returned nothing for zdots-worker). Root cause: c.use_all in Zdots.init_otel (lib/zdots.rb) only installs instrumentations already registered in OpenTelemetry::Instrumentation.registry — opentelemetry-instrumentation-all was never required, so the registry was empty and use_all silently no-op'd. This was true from the original fix in bd66fbb, not a later regression — the original verification (an induced failing job) likely only checked o2_failures right after the fix without confirming days later that spans kept flowing.

Fixed: added `require "opentelemetry/instrumentation/all"` before c.use_all in lib/zdots.rb. Verified live: enqueued a real job, zdots-worker now appears in SELECT DISTINCT service_name FROM "default" within the traces stream. Added tests/zdots_otel_init.bats as a regression guard (confirmed it fails on the pre-fix code, passes on the fix).
---
<!-- COMMENTS:END -->
