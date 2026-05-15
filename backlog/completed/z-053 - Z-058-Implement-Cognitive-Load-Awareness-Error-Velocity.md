---
id: Z-053
title: 'Z-058: Implement "Cognitive Load Awareness" (Error Velocity)'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:07'
updated_date: '2026-05-15 02:21'
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
- [x] #1 OTel sniffer detects bursts of non-zero exit codes (e.g., >3 errors in 5 mins).
- [x] #2 System triggers 'Calm Mode' (prompt color shift, notification).
- [x] #3 AI bridge offers a 'Log Triage' summary automatically when high cognitive load is detected.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented "Cognitive Load Awareness" (Error Velocity).
- Added `error-velocity` command to `bin/zdots-ctx` to detect bursts of failed commands from OTel traces.
- Created `lib/cognitive-load.bash` which triggers "Calm Mode" (visual cues and assistance tips) when frustration is detected.
- Integrated the check into the Zsh `precmd` hook, running every 5 commands to balance performance and responsiveness.
- Verified detection logic with high-error-rate simulation.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
