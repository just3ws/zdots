---
id: Z-153
title: >-
  Harden /docs-sync — mechanize AI-initializer-family coherence +
  fictional-reference linting
status: To Do
assignee: []
created_date: '2026-06-15 13:17'
labels:
  - docs
  - agent-ready
  - coherence
  - wave3
dependencies: []
ordinal: 44890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The /docs-sync skill (drafted in .claude/commands/docs-sync.md) gives a discipline for propagating a vocabulary/command-surface/contract change across the tiered AI-initializer family (AGENTS.md, CLAUDE.md, PI/AIDER/GEMINI/ROUTER.md, etc/prompts/*.md) and narrative docs. Right now its closing gate is partly manual. This task hardens it: turn the doc-005 R2 failure mode ('docs describe intent as present') into an enforced invariant, and give the tier-propagation map a single data source the skill and a linter both read. Sibling to /command-qc (per-command) and to Z-052 Living Docs (autonomous generation); the canonical R2 example to close is AGENTS.md §9 citing GLOSSARY.md/ONTOLOGY.md, which never existed (decision-009 makes terminology data, not markdown). Convergence over proliferation: extend docs-contract, do not add a competing doc checker.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The /docs-sync skill is ratified and discoverable (linked from CLAUDE.md Agent Skills section / skills index)
- [ ] #2 Fictional-reference linting is mechanized: docs-contract (or a linter it calls) FAILS when any tracked doc cites a command, file, or flag that does not exist — R2 becomes an invariant, not a manual step
- [ ] #3 A tier-propagation manifest (data, not prose) enumerates the AI-initializer family + which change-type touches which files; the skill and the linter both read it (single source of truth)
- [ ] #4 AGENTS.md §9 GLOSSARY.md/ONTOLOGY.md references are reconciled to point at the concept registry (decision-009) or CONTEXT.md — the canonical R2 example is closed
- [ ] #5 CHANGELOG.md remains generated (git-cliff), never hand-edited; the skill's gate regenerates rather than edits
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
