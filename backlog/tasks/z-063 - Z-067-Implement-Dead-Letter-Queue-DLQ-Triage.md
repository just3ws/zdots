---
id: Z-063
title: 'Z-067: Implement Dead-Letter Queue (DLQ) Triage'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 20:50'
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
- [ ] #1 Jobs failing more than Max Retries (e.g., 3) are marked 'dead' instead of 'failed'.
- [ ] #2 Add zdots-ctx triage command to review 'dead' jobs.
- [ ] #3 AI suggests fixes or reasons for 'dead' jobs during triage.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
