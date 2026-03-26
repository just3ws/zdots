---
id: Z-005
title: Implement Shell Observability and Control Plane
status: Done
assignee: []
created_date: '2026-03-26 15:07'
updated_date: '2026-03-26 15:15'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evolve Zdots into a self-describing environment with OpenTelemetry-like observability. This includes unique session identifiers, structured event tracing (command execution, navigation, errors), and a local 'control plane' for reporting shell health and activity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Generate a unique ZDOTS_SESSION_ID for every shell session
- [x] #2 Implement a structured tracing service (providers/trace) that logs to JSONL
- [x] #3 Add shell hooks (preexec, chpwd) to capture and report events with session context
- [x] #4 Integrate session reporting into bin/capabilities and bin/check
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Evolved Zdots into a self-describing environment with a structured observability control plane. 1. Implemented ZDOTS_SESSION_ID for session-level tracking. 2. Created providers/trace/local.zsh for JSONL structured logging. 3. Added shell hooks in conf.d/05-observability.zsh to capture chdir, exec, and session lifecycle events. 4. Developed bin/trace-verify for TDD-style verification of shell behavior. 5. Integrated observability health into bin/capabilities and added a verification step to the CI pipeline.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
