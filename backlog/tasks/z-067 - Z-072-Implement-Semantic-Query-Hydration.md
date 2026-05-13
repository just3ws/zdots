---
id: Z-067
title: 'Z-072: Implement Semantic Query & Hydration'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 22:58'
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
- [ ] #1 Update 'zdots-ctx query --semantic' to convert search terms to vectors and perform cosine similarity search.
- [ ] #2 Update 'ctx-mcp' with a new 'ctx_semantic_search' tool.
- [ ] #3 Update 'zdots-ctx hydrate' to optionally pull the most semantically relevant lessons for a given task tag.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
