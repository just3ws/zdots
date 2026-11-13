---
id: Z-362
title: >-
  [agent-issue] llama-ctl server install, when replacing an already-loaded
  com.zdots.llama-server, often leaves the
status: To Do
assignee: []
created_date: '2026-11-13T17:33:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 239895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7a084f400fe91d285e4b113951e052c5`

llama-ctl server install, when replacing an already-loaded com.zdots.llama-server, often leaves the service NOT loaded: it prints 'server started' (once with '[!!] check logs'), but launchctl print reports 'Could not find service' and :11500 is down. Seen 2 of 4 installs on 2026-11-13 while switching ZDOTS_AI_PROFILE; a second install fixes it. Likely bootout/bootstrap race (bootout returns before the old process exits). Readiness wait passed against the dying old server.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
