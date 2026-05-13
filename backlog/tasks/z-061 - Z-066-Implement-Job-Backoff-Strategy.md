---
id: Z-061
title: 'Z-066: Implement Job Backoff Strategy'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:50'
updated_date: '2026-05-13 21:20'
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
- [x] #1 Add next_run_at TIMESTAMPTZ column to jobs table.
- [x] #2 Failed jobs calculate next_run_at using exponential backoff (e.g., attempts^2 * 5 mins).
- [x] #3 Worker claim query only selects jobs where next_run_at <= CURRENT_TIMESTAMP.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented exponential backoff strategy for failed jobs in the Side-Effect Broker.
- Created migration `004_job_backoff.sql` adding `next_run_at` to the `jobs` table with an index on `(status, next_run_at, priority)`.
- Updated the worker claim query to only select jobs where `next_run_at <= CURRENT_TIMESTAMP`.
- Updated the failure handler in the worker to calculate `next_run_at` using Postgres `make_interval(mins => CAST(POWER(attempts + 1, 2) * 5 AS INTEGER))`, establishing exponential backoff (5 mins, 20 mins, 45 mins...).
- Updated `enqueue --force` and `requeue` to reset `next_run_at = CURRENT_TIMESTAMP`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
