---
id: Z-131
title: 'Narrow Searchable: drop dead semantic branch, own search strategy'
status: Done
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-15 11:07'
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
- [x] #1 the unused semantic: branch is removed or made live behind the interface
- [x] #2 callers no longer assemble embedding vectors inline
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Narrowed Searchable: search(term, semantic:) → search(term) (text path) + new semantic_search(term) that owns embedding assembly. Dead semantic: kwarg branch removed (confirmed no live callers — zdots-brain built vectors inline, bypassing the interface). Callers at zdots-brain shrink 13→3 lines: Methodology/Lesson.semantic_search(term).limit(5). Interface shrinks, implementation absorbs strategy. rspec 110 examples / 0 failures (wiki_exporter loader error pre-existing on main, unrelated); model-layer specs 4/0 on main. secret-scan clean. Commit 02a2934. NOTE (left as tech debt per task): the text path still does .all.select decrypt-all-in-Ruby — out of scope; revisit with DB-side FTS when row counts grow. (sonnet worktree fan-out, diff-reviewed before merge.)
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
