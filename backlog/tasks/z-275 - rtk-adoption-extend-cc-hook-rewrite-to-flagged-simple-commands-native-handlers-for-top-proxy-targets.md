---
id: Z-275
title: >-
  rtk adoption: extend cc-hook rewrite to flagged simple commands; native
  handlers for top proxy targets
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 151895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Measured 2026-08-01: rtk adoption inside CC sessions is 5.2% — ~405K tokens/30d of already-supported command shapes bypass the hook because the rewrite only covers unflagged simple commands. Separately, 1,253 segments route through rtk proxy (0% savings) where native handlers could exist.

Fix: (1) extend cc-hook rewrite rules to flagged single-binary invocations: git -C, grep -n/-rn/-c/-nE, ls -la, head -N, rg -n, sed -n, curl -s*; (2) run rtk discover against the proxy-target histogram and extend native grep/sed/curl matchers to the observed flag shapes. Each recovered grep ≈ 25.7% avg savings. (2026-08-01 system audit, usage — measured)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
