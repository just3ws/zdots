---
id: Z-287
title: Parallelize bin/check bats stage (bats --jobs) — 7min -> ~2-3min
status: To Do
assignee: []
created_date: '2026-08-02 16:43'
labels:
  - agent-ready
dependencies: []
priority: medium
ordinal: 163895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deferred from the 2026-08-02 perf pass when usage-intelligence took priority. Plan: bats --jobs N for parallel-safe suites; serial lane for DB/Redis/state-sharing suites (database.bats, cmd_analytics.bats drain tests, phi_boundary unified-log tests, anything writing shared XDG state). Gate: full suite green 3x consecutively before switching bin/check and the pre-push hook to it. Benefits: nightly zdots-watch run-check + pre-push gate both drop to ~2-3min.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
