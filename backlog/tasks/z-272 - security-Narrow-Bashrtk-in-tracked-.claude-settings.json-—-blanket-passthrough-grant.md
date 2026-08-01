---
id: Z-272
title: >-
  [security] Narrow Bash(rtk:*) in tracked .claude/settings.json — blanket
  passthrough grant
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - agent-reported
  - security
  - audit-filed
dependencies: []
priority: high
ordinal: 148895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Adversarial allowlist review 2026-08-01: 'Bash(rtk:*)' (tracked settings.json) auto-approves 'rtk proxy X' which runs X VERBATIM — observed unprompted in transcripts: rtk proxy sh (143), bash (33), python3 (36), zsh (8), perl (6), curl (42), git push (3). It also bypasses the deny on 'Bash(security find-generic-password:*)' in spirit ('rtk proxy security find-generic-password' does not match the deny prefix).

Operator decision (friction trade-off — the CC hook auto-rewrites simple commands to rtk, so narrowing may reintroduce prompts for rtk git add/commit): replace rtk:* with enumerated read-only leaves (rtk git status/log/diff, rtk grep, rtk ls, rtk find, rtk read, rtk gain, rtk discover, rtk summary) + explicitly decide the mutating set. Also consider a deny for 'Bash(rtk proxy sh:*)' / bash / python3 as a cheap first cut that keeps everything else frictionless.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
