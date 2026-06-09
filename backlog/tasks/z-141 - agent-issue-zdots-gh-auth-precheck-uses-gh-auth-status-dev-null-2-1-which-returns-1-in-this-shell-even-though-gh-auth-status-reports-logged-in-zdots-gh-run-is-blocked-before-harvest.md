---
id: Z-141
title: >-
  [agent-issue] zdots-gh auth precheck uses 'gh auth status >/dev/null 2>&1',
  which returns 1 in this shell even though 'gh auth status' reports logged in;
  zdots-gh run is blocked before harvest
status: To Do
assignee: []
created_date: '2026-06-09 18:26'
labels:
  - agent-reported
  - bug
dependencies: []
priority: high
ordinal: 32890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** high
**Trace ID:** `6112098e51f546e37392295b4b3f4790`

zdots-gh auth precheck uses 'gh auth status >/dev/null 2>&1', which returns 1 in this shell even though 'gh auth status' reports logged in; zdots-gh run is blocked before harvest

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
