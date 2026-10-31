---
id: Z-059
title: 'Z-064: Implement Session Residue Distillation'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:21'
updated_date: '2026-05-13 00:10'
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
- [x] #1 Post-exec hook or 'zdots-ctx capture' reads current OTel trace ID and command history.
- [x] #2 Local AI generates a 1-paragraph distillation of the session's 'Intent vs Result'.
- [x] #3 Distilled lesson is automatically proposed for insertion into the database.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented automated Session Residue Distillation in zdots-ctx.
- 'capture' command now gathers session history and OTel traces.
- AI-driven distillation produces a structured 'Intent vs Result' summary and a concise 'Lesson Learnt'.
- Lessons and residue are saved into the PostgreSQL Intelligence Suite with a user confirmation prompt.
- Verified distillation quality with a simulated session and automated database insertion.
- Seeded the database with 9 existing methodologies from ~/my/standards.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
