---
id: Z-275
title: >-
  rtk adoption: extend cc-hook rewrite to flagged simple commands; native
  handlers for top proxy targets
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
updated_date: '2026-08-02 17:20'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ADOPTION STORY CORRECTED (2026-08-02): rtk gain reports 96.2% aggregate savings over 39k commands — the hook path does the heavy lifting (rtk grep 7,719 calls / 1.0GB tokens saved; rtk read 4,003 / 505MB). The earlier 5.2% figure measured explicit interactive rtk usage only. Remaining real gaps: rtk proxy git (411) = hook fallback for git subcommands without native handlers (upstream handler wishlist), and agent-habit rtk proxy rg — now obsolete since the 'mangling' was the rg -r flag error (Z-285). Re-scope this task to: file the git-subcommand handler wishlist upstream; drop the adoption-drive framing.
<!-- SECTION:NOTES:END -->
