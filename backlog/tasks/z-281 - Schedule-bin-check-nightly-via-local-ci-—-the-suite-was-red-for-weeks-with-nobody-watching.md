---
id: Z-281
title: >-
  Schedule bin/check nightly via local-ci — the suite was red for weeks with
  nobody watching
status: To Do
assignee: []
created_date: '2026-08-01 18:12'
labels:
  - agent-reported
dependencies: []
priority: medium
ordinal: 157895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-08-01 discovery: bin/check's bats stage had 13 failures accumulated since ~2026-07-20 (svc-registry cutover, ctx_pipeline_events, beacon re-stamps, encryption column renames, phase-table growth, .sqliterc box mode, a hardcoded /Users/<user> path). Nothing runs the suite on a schedule, so assertion rot surfaces only when someone needs a green gate.

Proposal: local-ci (existing Platform Service) or a zdots-watch-style LaunchAgent runs bin/check nightly and reports transitions into the same worsening-only notify channel as zdots-watch (Z-268). Reuse zdots-watch's state-diff pattern; identity = failing test name. Keep it local-only.

Fixed instances: 32ecc2491 + 9e2b18ecd repaired all 13; this task is the detector so the class doesn't recur.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
