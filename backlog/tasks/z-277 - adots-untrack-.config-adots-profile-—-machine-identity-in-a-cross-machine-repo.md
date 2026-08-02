---
id: Z-277
title: >-
  adots: untrack .config/adots/profile — machine identity in a cross-machine
  repo
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - audit-filed
dependencies: []
priority: low
ordinal: 153895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
adots work branch tracks .config/adots/profile (content: the active machine profile, currently 'powerstation'). capabilities.sh documents profiles as machine identities. Any machine whose profile differs shows a perpetually-dirty tracked file, and a careless add/commit on one machine overwrites another's identity. Clean today only by coincidence (this host matches the committed value).

Fix in adots (operator): adots-git rm --cached .config/adots/profile, gitignore it, let bootstrap.sh/adots-doctor --fix seed per machine. Alternative if drift never bites: tracked default + documented per-machine override. (2026-08-01 platform audit, adots)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
