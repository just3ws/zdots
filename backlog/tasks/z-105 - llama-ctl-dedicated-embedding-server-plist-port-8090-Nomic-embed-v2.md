---
id: Z-105
title: 'llama-ctl: dedicated embedding server plist (port 8090, Nomic embed-v2)'
status: To Do
assignee: []
created_date: '2026-05-25 13:52'
labels:
  - ai
  - rag
  - llama-cpp
  - infra
dependencies:
  - Z-091
references:
  - etc/ai-models.yaml
  - bin/llama-ctl
  - bin/zdots-ctx
documentation:
  - docs/rag-activation.md
  - docs/ai-learning-map.md#1-rag-pipeline-retrieval-augmented-generation
priority: medium
ordinal: 3890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a second launchd plist for the dedicated embedding server. This unblocks RAG activation.

Current state: The chat server (port 8080, Qwen3-8B) has `embeddings: false` because --embeddings + --spec-draft-model causes a llama.cpp crash loop. RAG requires a separate embedding process.

Required:
- New plist: `com.zdots.llama-embed.plist`
- Port: 8090
- Model: `nomic-embed-text-v2-moe.Q8_0.gguf` (profile `embed`, 0.52GB, already in etc/ai-models.yaml)
- Flags: `--embeddings --pooling mean --ctx-size 512 --n-gpu-layers 99 --batch-size 2048 --ubatch-size 2048`
- No --spec-draft-model, no --flash-attn, parallel 1
- `llama-ctl` should drive plist generation from the `embed` profile in etc/ai-models.yaml
- `zdots-ctl up/down/check` must include the embed server

Also required:
- `ZDOTS_AI_EMBED_ENDPOINT=http://127.0.0.1:8090` plumbed through to zdots-ctx
- zdots-ctx capture to use embed endpoint for vector generation
- Verify embedding dimension: Nomic v2 MoE outputs 768 dims; current pgvector schema is 4096 — migration required (vector(4096) → vector(768))

See docs/rag-activation.md for the full activation checklist.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 llama-ctl install creates com.zdots.llama-embed.plist
- [ ] #2 curl http://127.0.0.1:8090/v1/embeddings returns 768-dim vector
- [ ] #3 zdots-ctl check reports embed server status
- [ ] #4 pgvector schema migrated to vector(768)
- [ ] #5 ZDOTS_CAPTURE_ENABLED=1 can be set after Keychain key provisioned
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
