---
id: Z-060
title: 'Z-065: Implement Worker Resilience (Heartbeats & Graceful Shutdown)'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:49'
labels:
  - intelligence-suite
  - queue
  - ops
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement worker resilience features. Add graceful shutdown traps to release claimed jobs if interrupted, and implement a heartbeat mechanism to quickly identify and recover from hard crashes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add SIGINT/SIGTERM trap to zdots-ctx worker to gracefully return running job to pending.
- [ ] #2 Worker updates jobs.updated_at every 60 seconds while processing long jobs.
- [ ] #3 clear-stale-jobs uses a 3-minute timeout based on heartbeats instead of 2 hours.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
