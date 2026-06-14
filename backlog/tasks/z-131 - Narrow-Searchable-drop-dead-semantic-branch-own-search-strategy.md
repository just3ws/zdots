---
id: Z-131
title: 'Narrow Searchable: drop dead semantic branch, own search strategy'
status: To Do
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-14 18:37'
labels:
  - architecture
  - refactor
  - wave2
dependencies:
  - Z-130
priority: low
ordinal: 22890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture candidate #6 (Speculative). Searchable exposes a wide interface hiding a decrypt-all scan.

Files: lib/zdots/models/searchable.rb, sbin/zdots-brain:232,251

Problem: search(term, semantic:) exposes a `semantic:` branch nobody calls (callers hand-roll embeddings at zdots-brain:232), while the live text path does .all.select — loading and decrypting every row before filtering in Ruby. lesson.rb acknowledges "revisit if row counts grow."

Solution: delete the dead semantic branch; move embedding assembly behind the interface so the implementation (not the caller) owns search strategy (bounded scan or embeddings).

Wins: interface shrinks while implementation absorbs strategy, deletes a dead code path, cost stops hiding behind a clean name, leverage (callers stop building vectors).

Note: lower urgency until row counts grow — the decrypt-all scan is acknowledged tech debt.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 the unused semantic: branch is removed or made live behind the interface
- [ ] #2 callers no longer assemble embedding vectors inline
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
