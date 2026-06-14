---
id: Z-040
title: Integrate llama-ctl config into ai-query for embedding size validation
status: To Do
assignee: []
created_date: '2026-04-19 02:32'
updated_date: '2026-06-14 18:35'
labels:
  - ai-query
  - llama-ctl
  - security
dependencies:
  - Z-130
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When ai-query is used with the /v1/embeddings endpoint (e.g., from RubyLLM), the input must fit within the server's ubatch_size (currently 2048 tokens). ai-query enforces a byte ceiling via AIQ_MAX_BYTES (default 32KB) but does not consult the server's actual physical batch size. Oversized embedding requests result in opaque HTTP 500 errors that are difficult to diagnose. By reading llama-ctl config --json at startup when available, ai-query can derive a tighter, server-aware ceiling for embedding calls and surface the limit clearly in debug output.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 When llama-ctl is present in PATH ai-query reads llama-ctl config --json at startup and caches the result for the session,For embedding calls (--mode embed or --embeddings flag) a token-estimate ceiling is derived from ubatch_size using the formula: ubatch_size * 3 bytes per token,When llama-ctl is not in PATH ai-query falls back silently to AIQ_MAX_BYTES with no error,The derived ceiling is shown in --debug output,docs/ai-query.md documents the llama-ctl integration the embed mode and the size derivation formula,Tests verify: ceiling is correctly derived from a mock llama-ctl config output; ai-query behaves correctly (uses AIQ_MAX_BYTES) when llama-ctl is absent
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
