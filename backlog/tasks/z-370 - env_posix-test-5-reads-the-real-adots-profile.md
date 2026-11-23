---
id: Z-370
title: env_posix test 5 reads the real adots profile
status: To Do
assignee: []
created_date: '2026-11-23T14:44:00Z'
labels:
  - tests
dependencies: []
ordinal: 247895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On a machine whose ~/.config/adots/profile is 'work', tests/env_posix.bats test 5 (Selects Brewfile.home by default) gets Brewfile.work. The test unsets ZDOTS_CONTEXT, but env.sh now reads the profile from the real XDG_CONFIG_HOME (ADR-0004/0005), so the machine's profile leaks in. Found 2026-11-23 after the fast-forward to 0893026.M3.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The test points XDG_CONFIG_HOME (or the profile path) at its tmpdir
- [ ] #2 env_posix.bats passes on a machine with a work profile
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
