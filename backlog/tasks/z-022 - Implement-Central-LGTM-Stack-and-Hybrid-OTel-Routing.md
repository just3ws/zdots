---
id: Z-022
title: Implement Central LGTM Stack and Hybrid OTel Routing
status: To Do
assignee: []
created_date: '2026-03-28 04:16'
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
- [ ] #1 Create etc/docker-compose.lgtm.yaml for the central observability hub
- [ ] #2 Update bin/local-ci to manage the LGTM stack lifecycle (start on boot, restartable)
- [ ] #3 Update etc/otel-collector.yaml to forward to the Colima OTLP endpoint
- [ ] #4 Document the hybrid observability routing (Host -> Collector -> Colima -> LGTM)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
