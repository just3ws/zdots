---
id: Z-160
title: document context-engine deploy requirement in SETUP.md and agent-guide
status: To Do
assignee: []
created_date: '2026-06-19 13:29'
labels:
  - docs
  - context-engine
  - deploy
dependencies: []
priority: low
ordinal: 51890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bin/deploy must be run after asset changes (propshaft precompile). SETUP.md and agent-guide should mention this for new-machine setup. Also: public/assets/ is gitignored — document that this is intentional (precompile output, not source).
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
