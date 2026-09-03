---
id: Z-336
title: >-
  [agent-issue] zdots-heal Gate 3 parser is stale: expects zdots-ctl status
  --json '{services:[{name,state}]}' but t
status: To Do
assignee: []
created_date: '2026-09-02 17:24'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 211895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `51a96ef723d9121d483864d519bd4b0b`

zdots-heal Gate 3 parser is stale: expects zdots-ctl status --json '{services:[{name,state}]}' but the schema is now a flat object ({colima:true,ai_server:true,...}). Gate 3 emits zero lines and silently passes even during a real outage. Fix: update the Gate 3 python snippet in .claude/commands/zdots-heal.md to the flat schema, or add a services[] compat view to zdots-ctl status --json.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
