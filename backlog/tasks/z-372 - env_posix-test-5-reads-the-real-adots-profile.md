---
id: Z-372
title: env_posix test 5 reads the real adots profile
status: To Do
assignee: []
created_date: '2026-11-23T23:33:42Z'
labels:
  - tests
dependencies: []
references:
  - https://github.com/just3ws/zdots/pull/59
  - >-
    https://github.com/just3ws/zdots/commit/283e5d4f272ad07401369b4f963f434bac7e6f42
type: bug
ordinal: 249895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On a machine whose ~/.config/adots/profile is work, tests/env_posix.bats test 5 (Selects Brewfile.home by default) gets Brewfile.work. The test unsets ZDOTS_CONTEXT, but env.sh reads the profile from the real XDG_CONFIG_HOME (ADR-0004/0005), so the machine profile leaks in. Imported from zdots PR #59, commit 283e5d4f; its downstream Z-370 ID collides with the existing local-model documentation task. Preserve the original Z-370 documentation record and track this distinct issue under a new ID.
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
