---
id: Z-065
title: 'Z-070: Implement Vector Schema'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 22:57'
labels:
  - intelligence-suite
  - postgres
  - schema
dependencies:
  - Z-064
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update the PostgreSQL Intelligence Suite schema to support vector embeddings. This requires the `pgvector` extension and adding appropriately sized vector columns to the core knowledge tables.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add 'embedding vector(N)' column to 'methodologies' table.
- [ ] #2 Add 'embedding vector(N)' column to 'lessons' table.
- [ ] #3 Create HNSW or IVFFlat indexes on the vector columns for performant cosine similarity search.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
