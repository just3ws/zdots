---
id: Z-288
title: Menu-bar platform pulse widget (SwiftBar) — ambient standing state
status: Done
assignee: []
created_date: '2026-08-02 17:25'
updated_date: '2026-08-02 18:29'
labels:
  - agent-ready
dependencies: []
priority: medium
ordinal: 164895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Native-app pick from 2026-08-02 session: detectors notify on WORSENING; nothing shows standing state ambiently. SwiftBar/xbar script (shell — zero new runtime): menu-bar dot green/amber/red from zdots-watch state files; dropdown = open warns/fails with their evidence paths (zdots-watch-runs/), caps attestation count, today's zdots-usage headline (top cmd, real-error leader), cc-burn budget line. Refresh 60s. All feeds already exist as files/CLIs — widget is pure consumption; no daemon, no sockets, local-only. Optional later: click-through opens evidence in $EDITOR via Hammerspoon URL handler.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DONE: bin/zdots-swiftbar (0.5s, state-file reads + one zdots-usage call) + ~/.swiftbar/zdots-pulse.1m.sh shim. Suite-state 'no state yet' handling; orphan-tmp cleanup hardening in zdots-watch. Man + contract green.
<!-- SECTION:NOTES:END -->
