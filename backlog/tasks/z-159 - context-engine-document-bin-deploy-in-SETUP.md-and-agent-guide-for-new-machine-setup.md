---
id: Z-159
title: >-
  context-engine: document bin/deploy in SETUP.md and agent-guide for
  new-machine setup
status: Done
assignee: []
created_date: '2026-06-19 13:07'
updated_date: '2026-06-30 00:12'
labels: []
dependencies: []
modified_files:
  - SETUP.md
  - bin/agent-guide
priority: low
ordinal: 50890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bin/deploy must be run after asset changes (propshaft precompile). public/assets/ is gitignored by design. SETUP.md and agent-guide should note this so the first deploy on a new machine does not 404 on CSS.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->



## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 SETUP.md documents bin/deploy step for context-engine first deploy
- [x] #2 agent-guide notes bin/deploy under Database Access section
<!-- AC:END -->
