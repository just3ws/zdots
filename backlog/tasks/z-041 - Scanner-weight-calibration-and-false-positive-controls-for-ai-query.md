---
id: Z-041
title: Scanner weight calibration and false-positive controls for ai-query
status: To Do
assignee: []
created_date: '2026-04-19 02:32'
updated_date: '2026-06-14 18:35'
labels:
  - ai-query
  - security
dependencies:
  - Z-130
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current scanner rule weights were set conservatively to catch obvious injections. After real-world use against technical documentation and shell content, some patterns (e.g., REDIRECT_INSTEAD scoring +15) produce medium scores on benign input. This task is a calibration pass based on observed false positives from the existing test fixtures, plus a per-mode score threshold override for modes that intentionally receive hostile content (classify-risk, inspect-prompt-injection). The goal is a scanner that is both precise on benign technical content and still catches genuine injection patterns.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Scanner rule weights are reviewed against all existing fixtures: plain.txt, injection_technical.txt, multiline.md, shell_content.txt,After calibration injection_technical.txt scores at medium risk level (not high) and plain.txt scores at low risk level,Per-mode block threshold overrides are implemented: classify-risk and inspect-prompt-injection modes use a higher block threshold (e.g., 90 instead of 60) since they are designed to receive adversarial content,--show-risk output format and field names are unchanged; calibration only affects block threshold behavior,All pre-existing scan tests continue to pass,Regression fixture files are added for any false-positive cases discovered during calibration
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
