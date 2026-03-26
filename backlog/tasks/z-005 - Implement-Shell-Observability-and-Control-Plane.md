---
id: Z-005
title: Implement Shell Observability and Control Plane
status: To Do
assignee: []
created_date: '2026-03-26 15:07'
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
- [ ] #1 Generate a unique ZDOTS_SESSION_ID for every shell session
- [ ] #2 Implement a structured tracing service (providers/trace) that logs to JSONL
- [ ] #3 Add shell hooks (preexec, chpwd) to capture and report events with session context
- [ ] #4 Integrate session reporting into bin/capabilities and bin/check
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
