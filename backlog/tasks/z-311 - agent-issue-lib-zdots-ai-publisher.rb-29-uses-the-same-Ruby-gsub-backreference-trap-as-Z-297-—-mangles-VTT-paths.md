---
id: Z-311
title: >-
  [agent-issue] lib/zdots/ai/publisher.rb:29 uses the same Ruby gsub
  backreference trap as Z-297 — mangles VTT paths
status: To Do
assignee: []
created_date: '2026-08-22 18:19'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 186895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

lib/zdots/ai/publisher.rb:29 uses the same Ruby gsub backreference trap as Z-297 — mangles VTT paths containing an apostrophe (no shell, ffmpeg filter parser only)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
