---
id: Z-287
title: Parallelize bin/check bats stage (bats --jobs) — 7min -> ~2-3min
status: Done
assignee: []
created_date: '2026-08-02 16:43'
updated_date: '2026-08-02 17:38'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DONE: two-lane runner in bin/check, no GNU parallel dep. 7:00 -> ~4:41 (greens 4:47 + 4:35, 788/788). Serial lane (16 stateful suites) is the new floor — promote suites out as they prove hermetic to reach the <3:00 OKR (O2-KR2).
<!-- SECTION:NOTES:END -->
