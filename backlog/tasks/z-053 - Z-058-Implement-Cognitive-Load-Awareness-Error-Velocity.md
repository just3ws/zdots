---
id: Z-053
title: 'Z-058: Implement "Cognitive Load Awareness" (Error Velocity)'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:07'
labels:
  - sentient-workbench
  - observability
  - ux
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Monitor 'Error Velocity' via OTel to detect user frustration or fatigue. Automate assistance (log summaries, theme shifts) to reduce cognitive load during high-error-rate sessions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OTel sniffer detects bursts of non-zero exit codes (e.g., >3 errors in 5 mins).
- [ ] #2 System triggers 'Calm Mode' (prompt color shift, notification).
- [ ] #3 AI bridge offers a 'Log Triage' summary automatically when high cognitive load is detected.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
