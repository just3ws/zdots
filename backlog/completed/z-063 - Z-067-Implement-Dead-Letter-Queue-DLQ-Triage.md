---
id: Z-063
title: 'Z-067: Implement Dead-Letter Queue (DLQ) Triage'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:50'
updated_date: '2026-05-13 21:28'
labels:
  - intelligence-suite
  - queue
  - ai
dependencies:
  - Z-061
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a Dead-Letter Queue (DLQ) pattern. Jobs that exhaust their retry attempts are marked as dead and surfaced for manual or AI-assisted triage, preventing permanent queue pollution.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Jobs failing more than Max Retries (e.g., 3) are marked 'dead' instead of 'failed'.
- [x] #2 Add zdots-ctx triage command to review 'dead' jobs.
- [x] #3 AI suggests fixes or reasons for 'dead' jobs during triage.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented Dead-Letter Queue (DLQ) Triage for the Side-Effect Broker.
- Created migration `005_dlq_status.sql` to add the `dead` status to the `job_status` ENUM.
- Updated the worker script to mark jobs as `dead` if they fail after 3 or more attempts, preventing them from infinite retries or clogging the `failed` queue.
- Implemented `zdots-ctx triage`, an interactive command that loops through `dead` jobs, uses `ai-query` to provide a concise root cause analysis and fix suggestions based on the error message, and prompts the user to either requeue (r), delete (d), or skip (s) the job.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
