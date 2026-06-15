---
id: Z-149
title: zdots dispatcher seam — the command-surface DSL root
status: To Do
assignee: []
created_date: '2026-06-15 01:48'
labels:
  - wave1
  - agent-ready
dependencies: []
ordinal: 40890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Thin additive 'zdots <noun> <verb>' router resolving to existing zdots-<noun> binaries/aliases. The missing Wave-0 substrate every command sits on; makes the grammar real and the docs (CLAUDE.md 'zdots doctor') honest. Convergence target for the 33 flattened zdots-* binaries. See decision-008.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 bin/zdots dispatcher resolves '<noun> <verb>' to the canonical binary with arg passthrough
- [ ] #2 --json flows through unchanged; --help lists the noun map
- [ ] #3 Existing entry points (zdots-ctl, zsvc, etc.) keep working unchanged — purely additive
- [ ] #4 CLAUDE.md/AGENTS.md command examples verified against the real dispatcher (no fictional grammar)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
