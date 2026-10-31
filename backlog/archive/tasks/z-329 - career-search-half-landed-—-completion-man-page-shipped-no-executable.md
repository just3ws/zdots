---
id: Z-329
title: 'career-search: half-landed — completion + man page shipped, no executable'
status: Done
assignee: []
created_date: '2026-09-01 13:05'
updated_date: '2026-09-01 13:45'
labels:
  - agent-reported
dependencies: []
priority: high
ordinal: 204895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
zdots-heal (2026-09-01) found functions/enabled/_career-search (zsh completion) and man/man1/career-search.1 both present but UNTRACKED, dated 2026-08-29. The command they describe does not exist anywhere on the machine: no bin/career-search, no career_search.py on PATH, in ~/my, or in the repo. Man page describes a ChatGPT-export mining suite (FTS5 + DuckDB) reading /Volumes/Dock_1TB/chatgpt-dump-2026-03/. Either the executable was never committed or this is abandoned scaffolding. Related to Z-326 (corpus integration plan).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decide: land the career-search executable in bin/ (+ track completion + man page), OR remove the orphaned completion and man page
- [ ] #2 If landed: passes /command-qc (help, man, completion, docs, agent-guide, capabilities, tests)
- [ ] #3 git status clean of career-search artifacts either way
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CONTAINMENT ISSUE, not a feature decision. Provenance: 2026-08-29 ~11:07-11:14, an Antigravity session ('chatgpt-dump & zdots-brain', handoff ~/.config/adots/handoffs/2026-08-29-3.md) built career_search.py — a personal career-evidence mining tool — on the external drive /Volumes/Dock_1TB/chatgpt-dump-2026-03/ (career_search.py 26KB exec, chatgpt_corpus.db 159MB, CAREER_SEARCH_ARCHITECTURE.md, man page, completion — all correctly on the volume). It then COPIED two of those artifacts into the zdots kernel repo: functions/enabled/_career-search and man/man1/career-search.1, as if career_search.py were a zdots command. It is not — it lives on an external drive and belongs to a separate personal project. Its zdots integration is only a future Phase 3 in Z-326 (proper bin/ command + Sequel migration), not a completion file pointing at /Volumes/. The completion was also inert (compdef for a command never on PATH in any zdots context). Resolution: removed both files from the zdots repo (untracked, never committed; originals intact on the external drive). Tree clean, docs-contract + completions tests green. Same session also did zdots-ctx add-methodology (chatgpt-corpus-mining), add-lesson (a96e60b6, tags: opensearch,pgvector,rrf,career-mining), and a bus-post to 'general' — KB entries are content-legit architecture notes; flagged for operator review re: scope. Broader question for operator: Antigravity session boundary — a project scoped to an external volume wrote tracked-file-shaped artifacts into the kernel repo + KB + bus.
<!-- SECTION:NOTES:END -->
