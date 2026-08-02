---
id: Z-272
title: >-
  [security] Narrow Bash(rtk:*) in tracked .claude/settings.json — blanket
  passthrough grant
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
updated_date: '2026-08-02 17:20'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EVIDENCE (2026-08-02 transcript scan, 38k commands / 50 sessions): 206 explicit interpreter invocations flowed through the Bash(rtk:*) blanket allow without a prompt — rtk proxy sh (139), bash (31), python3 (23), zsh (13). Verified the rtk hook does NOT generate these rewrites (rtk hook check: 'No rewrite' for sh/bash/python3), so denying the pattern breaks no hook flow; raw interpreter calls still work and prompt normally. READY-TO-APPLY PATCH (operator: CC classifier rightly blocks the agent from editing its own permission rules) — add to permissions.deny in .claude/settings.json: Bash(rtk proxy sh:*), Bash(rtk proxy bash:*), Bash(rtk proxy zsh:*), Bash(rtk proxy python3:*), Bash(rtk proxy python:*), Bash(rtk proxy ruby:*), Bash(rtk proxy node:*), Bash(rtk proxy perl:*). Remaining broader question (narrow rtk:* itself to named handlers) stays open but is much lower value once the proxy interpreter hole is shut.
<!-- SECTION:NOTES:END -->
