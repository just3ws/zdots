---
id: Z-268
title: >-
  zdots-watch: scheduled doctor loop with transition-only notify (cc-burn-watch
  pattern)
status: Done
assignee: []
created_date: '2026-08-01 09:56'
updated_date: '2026-08-01 16:20'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 144895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Every detector (zdots-doctor, zdots-ctl check, capabilities, cc-doctor) is invocation-only; the healing loop (/zdots-heal) needs a manually-launched CC session. Z-232 and Z-229 sat undetected until an agent looked. The platform already owns the right pattern: cc-burn-watch, launchd StartInterval=300, notifies only on severity TRANSITIONS.

Build: launchd agent running zdots-doctor --quiet + capabilities --json daily, diff pass/warn/fail vs last-run state file, macOS-notify only on worsening transitions. Local-only, no cloud, no repair verbs — continuous detection first. (2026-08-01 system audit, selfheal — verified)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DONE b009a0f: bin/zdots-watch (run/status/--install/--uninstall) + man page. Daily LaunchAgent, transition-only notify (new FAIL/warn identity or higher caps health_errors). Installed and seeded on this machine: 44 pass / 2 warn / 0 fail / caps=0. Identity dedup drops volatile tails (runs=N).
<!-- SECTION:NOTES:END -->
