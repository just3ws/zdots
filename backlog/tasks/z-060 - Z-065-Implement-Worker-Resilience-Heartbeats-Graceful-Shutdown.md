---
id: Z-060
title: 'Z-065: Implement Worker Resilience (Heartbeats & Graceful Shutdown)'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:49'
updated_date: '2026-05-13 21:06'
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
- [x] #1 Add SIGINT/SIGTERM trap to zdots-ctx worker to gracefully return running job to pending.
- [x] #2 Worker updates jobs.updated_at every 60 seconds while processing long jobs.
- [x] #3 clear-stale-jobs uses a 3-minute timeout based on heartbeats instead of 2 hours.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented worker resilience features in the Side-Effect Broker.
- Added a graceful shutdown `trap` for SIGINT and SIGTERM that safely returns the currently running job to a `pending` state before the script exits.
- Implemented a background heartbeat mechanism within `cmd_worker` that updates the `updated_at` timestamp every 60 seconds while a job is running.
- Updated `clear-stale-jobs` to use a 3-minute timeout by default, leveraging the new heartbeat to quickly identify and recover from hard worker crashes.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
