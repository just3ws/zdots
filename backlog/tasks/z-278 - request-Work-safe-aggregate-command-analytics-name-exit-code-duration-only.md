---
id: Z-278
title: >-
  [request] Work-safe aggregate command analytics: name + exit code + duration
  only
status: To Do
assignee: []
created_date: '2026-08-01 09:57'
labels:
  - agent-reported
  - request
  - audit-filed
dependencies: []
priority: low
ordinal: 154895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
AGENTS.md documents command_runs/Redis analytics as queryable, but ZDOTS_CMD_ANALYTICS=0 on work machines means the store does not exist here — agents burn probes discovering that, and exit-code failure analysis (which commands fail most = UX bugs) is impossible on the machine where most usage happens.

Operator decision: (1) /docs-sync note marking the analytics store home-machine-only, so agents stop probing; or (2) a work-safe aggregate mode recording only command NAME + exit code + duration (no args, nothing scrubbable) so failure-prone commands become measurable without PHI surface. The phi-history hook already proves the capture point exists. (2026-08-01 system audit, usage)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
