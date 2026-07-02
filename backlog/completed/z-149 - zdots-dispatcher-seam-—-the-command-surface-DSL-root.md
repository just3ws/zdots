---
id: Z-149
title: zdots dispatcher seam — the command-surface DSL root
status: Done
assignee: []
created_date: '2026-06-15 01:48'
updated_date: '2026-06-28 20:41'
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
- [x] #1 bin/zdots dispatcher resolves '<noun> <verb>' to the canonical binary with arg passthrough
- [x] #2 --json flows through unchanged; --help lists the noun map
- [x] #3 Existing entry points (zdots-ctl, zsvc, etc.) keep working unchanged — purely additive
- [x] #4 CLAUDE.md/AGENTS.md command examples verified against the real dispatcher (no fictional grammar)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
bin/zdots: ~25-line zsh script. `zdots <noun> [rest]` → `exec zdots-<noun> [rest]`. Unknown noun → error + usage. `--help` lists all `zdots-*` executables by stripping the prefix. Purely additive — no existing binary touched.

Verified: `zdots ctl status`, `zdots doctor --quiet`, `zdots ctx concept seam` all dispatch correctly. `--json` passthrough confirmed (exec preserves all args). 39 nouns registered via the existing `zdots-*` binaries.

Docs: CLAUDE.md code block updated (`zdots-doctor` → `zdots doctor`). AGENTS.md already consistent. All other hyphen-form references (`zdots-ctl`, `zsvc`) remain valid — both forms work.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
