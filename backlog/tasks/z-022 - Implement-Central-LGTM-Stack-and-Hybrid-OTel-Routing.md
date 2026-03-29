---
id: Z-022
title: Implement Central LGTM Stack and Hybrid OTel Routing
status: Done
assignee: []
created_date: '2026-03-28 04:16'
updated_date: '2026-03-29 03:10'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evolve shell observability into a system-wide control plane. This involves running a Grafana LGTM stack (Loki, Grafana, Tempo, Mimir) in Colima and configuring a bare metal OTel collector on the host to forward telemetry from the shell, apps, and agents to this central hub.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Create etc/docker-compose.lgtm.yaml for the central observability hub
- [x] #2 Update bin/local-ci to manage the LGTM stack lifecycle (start on boot, restartable)
- [x] #3 Update etc/otel-collector.yaml to forward to the Colima OTLP endpoint
- [x] #4 Document the hybrid observability routing (Host -> Collector -> Colima -> LGTM)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the central LGTM observability hub. 1. Created etc/docker-compose.lgtm.yaml for the Grafana/Loki/Tempo stack. 2. Integrated stack management into bin/local-ci (up, down, status, logs). 3. Configured the bare metal OTel collector (etc/otel-collector.yaml) to forward spans to the Colima hub. 4. Documented the hybrid multi-hop routing architecture in docs/architecture.md.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Deployed a central Grafana LGTM stack via etc/docker-compose.lgtm.yaml, integrated lifecycle management into bin/local-ci, configured bare-metal OTel collector to forward to the Colima hub, and documented the hybrid Host → Collector → Colima → LGTM routing in docs/architecture.md.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
