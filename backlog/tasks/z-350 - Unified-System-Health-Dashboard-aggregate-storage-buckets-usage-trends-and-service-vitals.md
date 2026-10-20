---
id: Z-350
title: >-
  Unified System Health Dashboard: aggregate storage buckets, usage trends, and
  service vitals
status: To Do
assignee: []
created_date: '2026-10-20 15:55'
labels:
  - agent-reported
  - feature
dependencies: []
priority: medium
type: feature
ordinal: 225895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Aggregate zdots-storage (multi-bucket storage footprint), zdots-usage (command frequencies, error rates, agent-vs-human sessions), and service health into a consolidated ambient view. Provide a unified CLI health overview (zdots pulse/health) and integrate into zdots-statusd and SwiftBar telemetry.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Consolidate storage, usage, and service vitals into a single unified JSON schema
- [ ] #2 Create a high-signal terminal overview command (zdots pulse / health)
- [ ] #3 Provide ambient web card integration on zdots-statusd (https://zdots.localhost)
- [ ] #4 Record weekly snapshot metrics to track storage growth and error velocities over time
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
