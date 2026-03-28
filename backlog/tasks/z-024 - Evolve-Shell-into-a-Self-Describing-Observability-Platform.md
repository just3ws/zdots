---
id: Z-024
title: Evolve Shell into a Self-Describing Observability Platform
status: To Do
assignee: []
created_date: '2026-03-28 04:56'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Expand the OTel control plane to support advanced integrations and prepare for Grafana alerting. This includes automatic error tracing, rich system metadata enrichment, and preparing the ground for Gemini-to-OTLP bridging.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Implement automatic Error Spans for non-zero command exit codes
- [ ] #2 Add system health attributes (Load, RAM) to the shell.heartbeat span
- [ ] #3 Integrate OTel into core upgrade/bootstrap workflows
- [ ] #4 Develop a 'Platform Discovery' spec for future Gemini integration
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
