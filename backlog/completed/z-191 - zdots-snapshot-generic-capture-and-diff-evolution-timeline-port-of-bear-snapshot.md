---
id: Z-191
title: >-
  zdots-snapshot: generic capture-and-diff evolution timeline (port of
  bear-snapshot)
status: Done
assignee: []
created_date: '2026-07-01 23:21'
updated_date: '2026-07-01 23:33'
labels:
  - feature
  - agent-ready
dependencies: []
priority: medium
ordinal: 87890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bear-snapshot: run any command, capture stdout under a name, diff against the previous capture — turning any re-runnable report into an evolution timeline. Zero domain content; perfect generic observability primitive. Write a zdots-native bin/zdots-snapshot (fresh implementation to zdots standards: help-from-header, flag-audit compliant, XDG state dir, bats). Pairs with telemetry + Session Residue; also serves the self-improvement loops (trend files for lessons-with-teeth, corrections-per-reprocess).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-snapshot <name> -- <cmd> captures stdout under XDG state and diffs vs previous run
- [ ] #2 list/show verbs; --help inert; bats coverage; docs-contract green
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shipped as bin/zdots-snapshot + tests/zdots_snapshot.bats (6/6) + contract wiring (docs_contract tested array, cli_contracts --help). Verified: capture/diff/exit-propagation/name-validation/list/show. Commit: see feat(bin): zdots-snapshot.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
