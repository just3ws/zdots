---
id: Z-302
title: >-
  [agent-issue] Gate 6 (skill/agent command-reference audit) has false positives
  when its extended-to-agents glob (a
status: To Do
assignee: []
created_date: '2026-08-10 12:56'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 177895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** friction
**Severity:** low
**Trace ID:** `60ae42c257383c0d1f1953df6ff769ca`

Gate 6 (skill/agent command-reference audit) has false positives when its extended-to-agents glob (added 2026-08-10) runs: 'zdots-local-analyst', 'zdots-only', 'zdots-specific' all report MISSING even though they are not bin/ commands — they are an agent's own name (self-reference in .claude/agents/zdots-local-analyst.md) and prose adjectives ('don't assume zdots-only', 'the zdots-specific carve-out') in zdots-patch-cycle.md and platform-sync.md. Pre-existing on the commands-only glob too (confirmed via git stash — not introduced by the agents extension). The regex has no way to distinguish a real command token from prose that happens to start with zdots-. Low priority: gate still catches real orphans, this is just noise in its output.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
