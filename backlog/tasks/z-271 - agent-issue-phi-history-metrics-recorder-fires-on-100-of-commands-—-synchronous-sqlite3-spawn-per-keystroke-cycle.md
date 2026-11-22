---
id: Z-271
title: >-
  [agent-issue] phi-history metrics recorder fires on 100% of commands —
  synchronous sqlite3 spawn per keystroke cycle
status: Done
assignee: []
created_date: '2026-08-01T09:57:00Z'
updated_date: '2026-11-22T11:53:15Z'
labels:
  - agent-reported
  - error
  - audit-filed
dependencies: []
priority: medium
ordinal: 147895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
conf.d/55-phi-history.zsh sets threshold_ms=1 for shell_hook_metrics_record, but the scrub spawn floor is ~7ms (measured 8.2ms avg; recorded MIN=6.98ms) — so the 'rare threshold-breaching' recorder fires on every command: synchronous mkdir + sqlite3 spawn+insert (~5.7ms) inside zshaddhistory, plus per-call CREATE TABLE/INDEX DDL in lib/shell_hook_metrics.bash. 3,769 'clean' rows confirm 100% recording. Net per-command prompt cost ≈25-30ms with the scrub.

Fix: raise record threshold to the 20ms print threshold (one line, 55-phi-history.zsh:54); background the write with (...) &! as 56-cmd-analytics does; hoist DDL to once-per-session like _ZCA_INIT. Saves ~6ms sync per command. (2026-08-01 system audit, perf — measured)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Raised threshold_ms from 1 to 20 in conf.d/55-phi-history.zsh, hoisted schema DDL once per DB (_SHM_INIT_DB) in lib/shell_hook_metrics.bash, and backgrounded sqlite3 INSERT in Zsh via &!. Steady-state shell_hook_metrics_record dropped 11.34ms -> 4.68ms (and 0ms on normal <20ms commands). Bats phi_boundary + cmd_analytics + history_intelligence: 88/88 passed.
<!-- SECTION:NOTES:END -->
