---
id: Z-270
title: 'Interactive startup: cache tool-init output in 71-shell-tools (364ms → ~200ms)'
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 146895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bin/bench: 364.3ms ±7.5ms; 223ms (61%) is conf.d/71-shell-tools.zsh. Components: 'source <(kubectl completion zsh)' 124ms (spawns kubectl every shell), atuin init 32ms, direnv 19ms, zoxide 5ms. The atuin zdefer is DEFEATED: 'zdefer eval "$(atuin init zsh ...)"' runs the command substitution synchronously at startup — the defer buys nothing.

Fix: (1) cache kubectl completion to XDG_CACHE keyed on kubectl version, source the file or zdefer it; (2) move atuin's command substitution inside a deferred function; (3) same cache for direnv/zoxide. Zero behavior change. (2026-08-01 system audit, perf — measured)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
