---
id: Z-332
title: career-search Tier 2 — semantic + hybrid retrieval (no Postgres dependency)
status: To Do
assignee: []
created_date: '2026-09-01 14:06'
updated_date: '2026-09-01 14:43'
labels:
  - agent-reported
dependencies: []
priority: medium
ordinal: 207895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Follow-up to career-search Tier 1 (landed in ~/my 2026-09-01, commits 1710ac5/8358ca0). Tier 1 is lexical-only (SQLite FTS5). Add semantic retrieval so vague queries work without knowing exact keywords. Approach avoids the Postgres migration in Z-326: (1) embed the ~32k corpus turns once via local zsvc embed (127.0.0.1:11501, 768-dim, PHI-safe) — store vectors in a sidecar numpy .npy or a duckdb table (~94MB, fits in memory); (2) add --semantic flag and hybrid RRF(BM25, cosine) ranking; (3) optional 'career-search ask "question"' — semantic top-k -> zdots-ask synthesis with conversation-ID citations (see docs/career-search/AGENT_GUIDE.md). Keep it in ~/my/bin/career-search, cache the vectors alongside the corpus in ~/my/data/career-search/ so it stays portable/offline. Z-326's Postgres phase becomes optional.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 career-search --semantic ranks by embedding similarity using local zsvc embed
- [ ] #2 hybrid mode fuses lexical + semantic (RRF or weighted)
- [ ] #3 vector index builds via a career-search command and is gitignored, portable, offline-capable
- [ ] #4 no new cloud dependency; degrades to lexical if embed service is down
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Update 2026-09-01: the LOCAL-LLM 'ask' mode is DONE (shipped in ~/my commit edac0e2). career-search ask retrieves top-k by BM25, a local model (ai-query/Qwen) synthesises a cited answer, degrades to raw excerpts if the LLM is down. keyword_query() builds the lexical query from a natural-language question. This task now narrows to just the SEMANTIC retrieval layer that stacks under the existing 'ask': embed the ~32k docs once via zsvc embed (768-dim), store vectors in ~/my/data/career-search/ (portable, gitignored), add hybrid BM25+cosine (RRF) ranking behind a --semantic flag. Generic — belongs in ~/my/lib/archive_search.py so every archive tool inherits it. Pattern + engine now documented at ~/my/docs/archive-tooling/README.md.
<!-- SECTION:NOTES:END -->
