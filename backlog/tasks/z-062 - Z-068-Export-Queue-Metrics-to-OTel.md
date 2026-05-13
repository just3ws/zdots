---
id: Z-062
title: 'Z-068: Export Queue Metrics to OTel'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:50'
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
- [ ] #1 Background job or cron periodically polls zdots-ctx status --json.
- [ ] #2 Pending job count is emitted as a gauge metric to the local otel-collector.
- [ ] #3 Grafana LGTM stack can visualize queue depth over time.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
