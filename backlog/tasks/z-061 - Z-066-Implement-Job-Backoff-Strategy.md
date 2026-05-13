---
id: Z-061
title: 'Z-066: Implement Job Backoff Strategy'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:50'
labels:
  - intelligence-suite
  - queue
  - reliability
dependencies:
  - Z-060
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement exponential backoff for failed jobs to prevent immediate retry thrashing. This is critical for handling temporary failures like rate limits or network partitions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add next_run_at TIMESTAMPTZ column to jobs table.
- [ ] #2 Failed jobs calculate next_run_at using exponential backoff (e.g., attempts^2 * 5 mins).
- [ ] #3 Worker claim query only selects jobs where next_run_at <= CURRENT_TIMESTAMP.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
