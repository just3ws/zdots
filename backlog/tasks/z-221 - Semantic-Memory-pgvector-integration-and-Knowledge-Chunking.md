---
id: Z-221
title: Semantic Memory - pgvector integration and Knowledge Chunking
status: To Do
assignee: []
created_date: '2026-07-12 07:50'
updated_date: '2026-07-12 07:50'
labels:
  - Phase 2
milestone: m-4
dependencies:
  - Z-171
  - Z-204
priority: high
---

## Description
<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate `pgvector` into the `context-engine` database to provide a semantic search layer over historical transcripts. Create a `knowledge_chunks` table and an `embedded` pipeline stage that slices diarized transcripts into paragraph-level segments, embeds them via a local model (e.g. `nomic-embed-text`), and stores the vectors for cosine-similarity retrieval via `ai-query`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `pgvector` extension enabled in PostgreSQL and `knowledge_chunks` schema defined.
- [ ] #2 `embedded` stage added to `ingest_media.rb` pipeline (running after `timeline`).
- [ ] #3 Slices transcripts into small chunks and generates vector embeddings locally.
- [ ] #4 Retrieval mechanism allows querying across the entire video corpus by semantic intent.
<!-- AC:END -->

## Implementation Notes
<!-- SECTION:NOTES:BEGIN -->
This is the foundational component for the autonomous research assistant for authoring books and articles on the Software Craftsmanship movement.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
