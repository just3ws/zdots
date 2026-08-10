---
id: Z-301
title: >-
  [agent-issue] Gate 9-A (self-describing skills audit, added 2026-08-10):
  .claude/commands/zdots-audit.md has YAML
status: To Do
assignee: []
created_date: '2026-08-10 12:55'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 176895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** friction
**Severity:** low
**Trace ID:** `60ae42c257383c0d1f1953df6ff769ca`

Gate 9-A (self-describing skills audit, added 2026-08-10): .claude/commands/zdots-audit.md has YAML frontmatter but no 'name:' field. .claude/commands/zdots.md has no frontmatter block at all. Both fail the new Gate 9-A frontmatter-presence check in zdots-heal.md. Not blocking anything today — flagging so they get a name: field added for consistency with every other skill.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
