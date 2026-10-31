---
id: Z-030
title: Fix OTel Collector connection to Colima Docker socket
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-04-03 22:23'
updated_date: '2026-04-03 23:01'
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
- [x] #1 OTel collector can connect to Docker daemon via Colima socket.
- [x] #2 'docker_stats' receiver in 'etc/otel-collector.yaml' uses a portable path (using '${env:HOME}').
- [x] #3 OTel collector service starts without "Cannot connect to the Docker daemon" errors.
- [x] #4 'bin/otel-collector validate' passes.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updated etc/otel-collector.yaml to use ${env:HOME}/.config/colima/default/docker.sock.

Verified with bin/otel-collector validate.

Restarted collector and confirmed successful startup in logs.

Confirmed no more "Cannot connect to the Docker daemon" errors after the fix.

Ran make check and all tests passed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Updated etc/otel-collector.yaml to use the Colima Docker socket path via ${env:HOME}/.config/colima/default/docker.sock. Verified that the collector now starts successfully without "Cannot connect to the Docker daemon" errors and that all project-wide checks (make check) pass.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output
- [x] #2 file path
- [x] #3 or test result)
- [x] #4 make check passes with output captured in task notes or commit message
- [x] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
