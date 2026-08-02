---
id: Z-267
title: >-
  Doctor detector pack: launchd flap/last-exit, dead-inode scan, install-set
  manifest
status: To Do
assignee: []
created_date: '2026-08-01 09:56'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: high
ordinal: 143895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three verified detection gaps (all held under adversarial verify 2026-08-01):
1. Flap blindness: all 7 KeepAlive services restart every 30s forever with zero signal (Z-229 class: worker failure storm while brief said 'clean'). svc-registry extracts state/pid but not last-exit. Add doctor check: parse launchctl print for last exit code != 0, warn with zsvc diag hint.
2. Dead-inode blindness: the exact gap that let the embed deleter hide for 5 occurrences (Z-250/Z-260). Zero +L1 scans anywhere. Add doctor check: lsof -p <pid> +L1 per com.zdots PID — warn 'process holds deleted file, on-disk truth diverged'.
3. Install-set drift: work machine ran with NO log rotation until openobserve.log hit 96M (Z-263). Add doctor check comparing expected com.zdots.* label manifest vs launchctl print gui/$UID.
All pure-read, PHI-safe, in the existing doctor Services section. (2026-08-01 system audit, selfheal — verified)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
