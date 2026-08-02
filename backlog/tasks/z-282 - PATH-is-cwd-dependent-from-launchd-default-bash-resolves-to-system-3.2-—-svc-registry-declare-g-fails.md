---
id: Z-282
title: >-
  PATH is cwd-dependent: from / (launchd default) bash resolves to system 3.2 —
  svc-registry declare -g fails
status: To Do
assignee: []
created_date: '2026-08-02 11:37'
labels:
  - agent-reported
dependencies: []
priority: high
ordinal: 158895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found 2026-08-02 via zdots-watch launchd runs. Repro: 'cd / && env -i HOME=$HOME /bin/zsh -lic "command -v bash"' -> /bin/bash 3.2 (and command -v prints the anomalous //bin/bash, suggesting a degenerate PATH element); same from $ZDOTDIR -> /opt/homebrew/bin/bash 5.3. Consequence: any '#!/usr/bin/env bash' zdots tool sourcing lib/svc-registry.bash (declare -Ag, bash4+) breaks when invoked from cwd=/ — i.e., every launchd/cron consumer that does not set WorkingDirectory. Bit zdots-logs check under the zdots-watch doctor agent: rc=2 tool error was reported as 'log files exceed 500M' (doctor conflation now fixed to report UNVERIFIED instead; watch plists now set WorkingDirectory=$ZDOTDIR as mitigation). ROOT CAUSE UNFIXED: trace where env.sh/conf.d PATH assembly (or a mise/direnv per-dir hook) makes homebrew precedence depend on cwd. env.sh is load-bearing — needs its own careful pass, not a drive-by.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
