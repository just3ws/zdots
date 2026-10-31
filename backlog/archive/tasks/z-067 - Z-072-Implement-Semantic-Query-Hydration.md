---
id: Z-067
title: 'Z-072: Implement Semantic Query & Hydration'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 22:58'
updated_date: '2026-05-14 01:26'
labels:
  - intelligence-suite
  - cli
  - mcp
dependencies:
  - Z-066
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Close the loop by allowing users and AI agents to semantically search the intelligence suite. Update the CLI bridge and MCP server to translate queries into vectors and perform similarity matching against the database.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Update 'zdots-ctx query --semantic' to convert search terms to vectors and perform cosine similarity search.
- [x] #2 Update 'ctx-mcp' with a new 'ctx_semantic_search' tool.
- [x] #3 Update 'zdots-ctx hydrate' to optionally pull the most semantically relevant lessons for a given task tag.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented the Semantic Query & Hydration layer.
- Upgraded `zdots-ctx query` with a `--semantic` flag that translates queries into vectors and performs cosine similarity matching using `pgvector`.
- Added `ctx_semantic_search` to the `ctx-mcp` server, allowing AI agents to perform semantic lookups over methodologies and lessons.
- Upgraded `zdots-ctx hydrate` to optionally perform semantic retrieval of lessons based on task tags or topics.
- Verified end-to-end flow: from adding a methodology to automatic embedding and finally semantically searching for it.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
