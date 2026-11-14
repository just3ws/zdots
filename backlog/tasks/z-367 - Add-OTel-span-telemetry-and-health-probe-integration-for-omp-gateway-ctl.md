---
id: Z-367
title: Add OTel span telemetry and health probe integration for omp-gateway-ctl
status: To Do
assignee: []
created_date: '2026-11-14T22:48:00Z'
labels:
  - ai
  - omp
  - observability
dependencies: []
priority: medium
ordinal: 244895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wire omp-gateway-ctl (127.0.0.1:11509 auth-broker and 127.0.0.1:11510 auth-gateway) into capabilities --json and optional OTel collector metrics so multi-account fallback and quota utilization are observable on loopback.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 capabilities --json reports omp and omp-gateway-ctl status
- [ ] #2 Work-context boundary tests in tests/ cover zomp and omp-gateway-ctl
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
