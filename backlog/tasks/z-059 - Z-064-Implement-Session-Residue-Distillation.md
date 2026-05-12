---
id: Z-059
title: 'Z-064: Implement Session Residue Distillation'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:21'
labels:
  - intelligence-suite
  - ai
  - automation
dependencies:
  - Z-058
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the automated capture of session 'residue'. This uses OTel traces and shell history to suggest distilled lessons to the database, ensuring your intelligence suite grows as you work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Post-exec hook or 'zdots-ctx capture' reads current OTel trace ID and command history.
- [ ] #2 Local AI generates a 1-paragraph distillation of the session's 'Intent vs Result'.
- [ ] #3 Distilled lesson is automatically proposed for insertion into the database.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
