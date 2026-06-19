---
id: Z-159
title: >-
  context-engine: document bin/deploy in SETUP.md and agent-guide for
  new-machine setup
status: To Do
assignee: []
created_date: '2026-06-19 13:07'
labels: []
dependencies: []
priority: low
ordinal: 50890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bin/deploy must be run after asset changes (propshaft precompile). public/assets/ is gitignored by design. SETUP.md and agent-guide should note this so the first deploy on a new machine does not 404 on CSS.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
