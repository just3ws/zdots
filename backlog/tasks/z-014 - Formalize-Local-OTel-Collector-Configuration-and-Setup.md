---
id: Z-014
title: Formalize Local OTel Collector Configuration and Setup
status: Done
assignee: []
created_date: '2026-03-27 16:29'
updated_date: '2026-03-29 03:13'
labels: []
milestone: m-1
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
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Standardized etc/otel-collector.yaml and bridged host telemetry to the Colima hub.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created etc/otel-collector.yaml with standardized span processors and bridged host telemetry to the Colima LGTM hub. Original AC#2 (document otel-desktop-viewer setup) was rendered obsolete by Z-022's LGTM stack — the collector now routes to Grafana/Tempo instead. Collector setup is documented in docs/architecture.md as part of the hybrid routing architecture.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
