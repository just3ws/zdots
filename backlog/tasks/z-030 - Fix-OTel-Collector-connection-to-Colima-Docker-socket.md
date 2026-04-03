---
id: Z-030
title: Fix OTel Collector connection to Colima Docker socket
status: In Progress
assignee:
  - '@gemini-cli'
created_date: '2026-04-03 22:23'
updated_date: '2026-04-03 22:23'
labels: []
milestone: 'm-1: Radical Observability'
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The local OpenTelemetry collector is failing to start because it cannot connect to the Docker daemon at unix:///var/run/docker.sock. Colima's socket on macOS is located at ~/.config/colima/default/docker.sock. This task involves updating the collector configuration and potentially the service definition to correctly find the Colima socket.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OTel collector can connect to Docker daemon via Colima socket.
- [ ] #2 'docker_stats' receiver in 'etc/otel-collector.yaml' uses a portable path (using '${env:HOME}').
- [ ] #3 OTel collector service starts without "Cannot connect to the Docker daemon" errors.
- [ ] #4 'bin/otel-collector validate' passes.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
