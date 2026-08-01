---
id: Z-265
title: >-
  zdots-completion-gen: generate #compdef stubs from --help; drift check for
  curated ones
status: To Do
assignee: []
created_date: '2026-08-01 09:56'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 141895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Completion coverage is 20 of ~93 user-facing commands; high-frequency commands (ztask, zmorning, zdots-issue, cc-burn, colima-status, session-debrief) have none. command-qc records the zsynod incident: 4 new verbs shipped while _zsynod ended at 'version' — found by the operator, not the process. No generator, no drift check.

Fix: (1) zdots-completion-gen — parse the two house --help patterns (usage() heredoc Commands:/Options:, header-comment) into #compdef stubs; fills gaps, never overwrites curated files (zdots-man-gen contract). (2) docs-contract check: every curated completion's subs cover the command's dispatch verbs (report-only first). (2026-08-01 system audit, cliux)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
