---
id: Z-064
title: 'Z-069: Configure Local Embedding Model'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-13 22:57'
updated_date: '2026-05-13 22:59'
labels:
  - intelligence-suite
  - ai
  - vector
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure the local AI stack is configured to generate vector embeddings. This involves verifying that the current `llama.cpp` endpoint (`/v1/embeddings`) works correctly and determining the vector dimension size (N) required for the PostgreSQL schema.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Verify llama.cpp supports /v1/embeddings with the current model or configure a secondary process.
- [x] #2 Determine the exact embedding dimension size (N) for the active model.
- [x] #3 Document the embedding model configuration in docs/llama-cpp.md or etc/ai-models.yaml.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Verified the local embedding model capabilities.
- Tested the `/v1/embeddings` endpoint on the local `llama.cpp` server.
- Confirmed the endpoint works and determined that the embedding dimension size (N) for the active `Qwen2.5-Coder` model is `3584`.
- Documented this dimension size in `docs/llama-cpp.md`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
