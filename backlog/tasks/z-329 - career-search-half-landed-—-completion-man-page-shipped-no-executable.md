---
id: Z-329
title: 'career-search: half-landed — completion + man page shipped, no executable'
status: To Do
assignee: []
created_date: '2026-09-01 13:05'
labels:
  - agent-reported
dependencies: []
priority: medium
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
