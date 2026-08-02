---
id: Z-284
title: 'zdots-watch keeps the evidence — persist last N full run outputs (evidence #4)'
status: To Do
assignee: []
created_date: '2026-08-02 14:57'
labels:
  - agent-ready
dependencies: []
priority: medium
ordinal: 160895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
OBSERVED GAP (2026-08-02): the doctor's false 'log files exceed 500M' under launchd could not be diagnosed from state — zdots-watch keeps only counts + identity lines, so the raw zdots-doctor/bin/check output that would have named the real error (bash-3.2 declare -g) was gone. Diagnosis required live reproduction.

CHANGE: cmd_run and cmd_run-check write the full captured output to $XDG_STATE_HOME/zsh/zdots-watch-runs/{doctor,check}-<ts>.log, keep the newest N (default 7, knob ZDOTS_WATCH_KEEP), prune older. status gains 'evidence: <path>' line pointing at the latest. ~10-15 lines per verb; no notify-behavior change. Every future worsening transition then ships with its evidence attached.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
