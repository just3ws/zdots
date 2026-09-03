---
id: Z-340
title: >-
  [agent-issue] zdots-heal Gate 6 regex matches prose and agent names as MISSING
  commands
status: To Do
assignee: []
created_date: '2026-09-03 13:32'
updated_date: '2026-09-03 13:32'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 215895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
During /zdots-heal Gate 6, the orphaned-command-reference scan printed 4 false positives:

  MISSING: zdots-local-analyst   <- an agent (.claude/agents/zdots-local-analyst.md), not a bin command
  MISSING: zdots-only            <- prose: 'don't assume zdots-only' (zdots-patch-cycle.md)
  MISSING: zdots-side            <- prose: 'zdots-side doc drift' (interop-registry.md)
  MISSING: zdots-specific        <- prose: 'the zdots-specific carve-out' (platform-sync.md)

## Cause
The Gate 6 regex 'zdots-[a-z0-9-]+' greedily matches hyphenated English adjectives in skill prose, and does not exclude agent basenames when resolving 'is this a real command'.

## Fix
In .claude/commands/zdots-heal.md Gate 6:
- add a word-boundary / stop the token at a following letter that forms a common word suffix, or maintain a small ignore list (only|side|specific|specific|wide|...); and
- treat '.claude/agents/<name>.md' as a valid resolution target the same way '.claude/commands/<name>.md' already is.

Cosmetic: no real orphaned reference exists. Noise only.
Filed from /zdots-heal 2026-09-03.
<!-- SECTION:DESCRIPTION:END -->
