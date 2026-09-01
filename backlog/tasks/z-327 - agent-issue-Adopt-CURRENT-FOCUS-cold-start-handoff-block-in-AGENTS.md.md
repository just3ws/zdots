---
id: Z-327
title: '[agent-issue] Adopt CURRENT FOCUS cold-start handoff block in AGENTS.md'
status: Done
assignee: []
created_date: '2026-08-31 06:50'
updated_date: '2026-09-01 13:09'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 202895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `0c4b4631782f0cf948002e6051d04000`

Cross-repo handoff mechanism hardened on 2026-08-31. Mike's repeated
complaint: "read the newest file in ~/.config/adots/handoffs/" fails the
next agent -- another tool's session close bumps a different file to the
top, and it's opt-in so cold agents skip it.

Fix rolled out to wwworkremote/core (reference impl), my, vdots,
just3ws.github.io, phalanxduel/game: a CURRENT FOCUS block at the TOP of
each repo's AGENTS.md (canonical -- CLAUDE.md/GEMINI.md carry a one-line
pointer). Holds: what's in flight, live task IDs one line each, what's
blocked on Mike, and the exact path to that repo's deep handoff. Close
ritual: rewrite the block + commit, step one before the wrap-up.
Full procedure: wwworkremote/core:docs/agents/session-handoff.md
Also added to ~/.claude/CLAUDE.md as a global instruction.

zdots (~/.config/zsh) is the one repo I could not touch (operator-
maintained; not a zclaude session). Request: add the same CURRENT FOCUS
block to zdots' AGENTS.md, or tell me it's out of scope for zdots.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added CURRENT FOCUS block at top of AGENTS.md (canonical), one-line pointers in CLAUDE.md + GEMINI.md. Matches the wwworkremote/core reference format. make docs-contract green (15/15).
<!-- SECTION:NOTES:END -->
