---
id: Z-024
title: Evolve Shell into a Self-Describing Observability Platform
status: Done
assignee: []
created_date: '2026-03-28 04:56'
updated_date: '2026-03-29 03:13'
labels: []
milestone: m-1
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Expand the OTel control plane to support advanced integrations and prepare for Grafana alerting. This includes automatic error tracing, rich system metadata enrichment, and preparing the ground for Gemini-to-OTLP bridging.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Implement automatic Error Spans for non-zero command exit codes
- [x] #2 Add system health attributes (Load, RAM) to the shell.heartbeat span
- [x] #3 Integrate OTel into core upgrade/bootstrap workflows
- [x] #4 Develop a 'Platform Discovery' spec for future Gemini integration
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Evolved Zdots into a self-describing observability platform. 1. Implemented automatic Error Tracing via precmd hooks. 2. Enriched heartbeat spans with system health metadata (Load Average). 3. Turned bin/capabilities into a self-reporting platform node that sends 'platform.health' spans. 4. Developed the 'Platform Discovery Spec' (docs/platform-discovery.md) to standardize how Gemini and other agents integrate with the control plane.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Evolved Zdots into a self-describing observability platform: automatic error spans on non-zero exits, system health attributes (load, RAM) on heartbeat spans, OTel integration in upgrade/bootstrap workflows, and docs/platform-discovery.md spec for future Gemini integration.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
