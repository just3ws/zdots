---
id: Z-062
title: 'Z-068: Export Queue Metrics to OTel'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:50'
updated_date: '2026-05-13 21:33'
labels:
  - intelligence-suite
  - queue
  - observability
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate the Side-Effect Broker with the Observability stack by emitting queue depth metrics to OTel. This allows for visual monitoring of job throughput and backlog.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Background job or cron periodically polls zdots-ctx status --json.
- [x] #2 Pending job count is emitted as a gauge metric to the local otel-collector.
- [x] #3 Grafana LGTM stack can visualize queue depth over time.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented queue metrics export to the OTel stack.
- Created `zdots-ctx metrics-loop` which runs continuously, querying Postgres for `pending` and `dead` job counts.
- It dynamically generates an OTLP JSON payload with timeUnixNano calculated via Python/gdate/date.
- The metrics are posted via HTTP to the local `otel-collector` (port 4318) as gauge data points `zdots.jobs.pending` and `zdots.jobs.dead`.
- Integrated graceful shutdown trap into the metrics loop.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
