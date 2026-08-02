---
id: Z-285
title: >-
  rtk rg handler corrupts match output — exempt rg from auto-rewrite until fixed
  (tooling #6)
status: To Do
assignee: []
created_date: '2026-08-02 14:57'
labels:
  - agent-ready
dependencies: []
priority: medium
ordinal: 161895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
REPRO (twice, 2026-08-02 session): rg invocations auto-rewritten through rtk returned results with the matched string REPLACED by 'n' (e.g. searching lib/ for 'scrub_failure' printed lines reading "suppressed via n"; searching for 'def self.db' printed bare 'n'). Each occurrence silently corrupts evidence and cost a re-run via rtk proxy. rg is presumably rtk's most-used handler (rtk grep alone averages 25.7% savings — L4), so a correctness bug here is also the main adoption blocker for Z-275 (adoption 5.2%).

ACTIONS: (1) locate the CC auto-rewrite hook (not in tracked .claude/settings.json — likely user-level ~/.claude config) and exempt rg/grep until the handler is proven faithful; (2) fix or file upstream in the rtk repo: handler must never alter matched text — add a golden test: rtk rg output byte-identical to raw rg for a fixture tree; (3) re-enable the rewrite once the golden test passes. Verify with: rtk rg 'scrub_failure' conf.d/ vs rtk proxy rg — outputs must match.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
