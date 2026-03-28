---
id: Z-014
title: Formalize Local OTel Collector Configuration and Setup
status: Done
assignee: []
created_date: '2026-03-27 16:29'
updated_date: '2026-03-28 17:23'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Establish a standardized configuration and setup process for a local OpenTelemetry collector. This ensures that the shell's OTLP traces have a reliable local destination for analysis and visualization.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Create etc/otel-collector.yaml with standardized span processors
- [ ] #2 Document setup for otel-desktop-viewer or similar local collector
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Standardized etc/otel-collector.yaml and bridged host telemetry to the Colima hub.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
