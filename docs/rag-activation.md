# RAG Activation Guide

This document covers the steps to activate the RAG pipeline.

## Current State

RAG is **not active**. One remaining blocker:

1. `ZDOTS_CAPTURE_ENABLED=0` — capture requires the DB encryption key (see below)

### What's already done

- **Embedding server** running on `:8090` (Nomic embed-v2 MoE, 768-dim) managed by `llama-ctl install-embed`
- **pgvector schema** migrated to `vector(768)` with HNSW indexes (`db/migrations/20260525120000_embed_dimension_nomic.rb`)
- **`ZDOTS_AI_EMBED_ENDPOINT`** defaulted to `http://127.0.0.1:8090` in `.zdots.env`
- **Ruby `EmbedConnection`** (`lib/zdots/ai/client.rb`) uses the embed server directly — bypasses RubyLLM
- **`zdots-ctl check`** verifies embed server health, plist registration, and nginx TLS proxy

## Remaining step: DB encryption key

The key must come from macOS Keychain. **Never** store it in `.zdots.env`, `.zdots.local`, or any tracked file.

```bash
# 1. Provision the key (one-time — generates a random 32-byte key)
security add-generic-password \
  -a "$USER" \
  -s "ZDOTS_DB_ENCRYPTION_KEY" \
  -w "$(openssl rand -hex 32)" \
  -T "" \
  ~/Library/Keychains/login.keychain-db

# 2. Verify retrieval works
security find-generic-password -a "$USER" -s "ZDOTS_DB_ENCRYPTION_KEY" -w
```

Then create/update `.zdots.local` (gitignored, never committed):

```bash
# Retrieve key at shell startup from Keychain
export ZDOTS_DB_ENCRYPTION_KEY=$(
  security find-generic-password -a "$USER" -s "ZDOTS_DB_ENCRYPTION_KEY" -w 2>/dev/null
)

# Enable capture (requires key above + embed server running on :8090)
export ZDOTS_CAPTURE_ENABLED=1
```

```bash
# 3. Apply any pending migrations
zdots-ctx migrate

# 4. Verify schema is current
zdots-ctl check   # should show 0 failures
```

## Activation checklist

- [ ] `security add-generic-password` run — key provisioned in Keychain
- [ ] `.zdots.local` created with `ZDOTS_DB_ENCRYPTION_KEY` retrieval + `ZDOTS_CAPTURE_ENABLED=1`
- [ ] `zdots-ctx migrate` run — schema at current version
- [ ] `zdots-ctl check` — 0 failures
- [ ] Test: start a new shell session, run a few commands, then `zdots-ctx list` to verify capture

## Architecture

| Layer | Component | State |
|---|---|---|
| Capture gate | `ZDOTS_CAPTURE_ENABLED` | Off (pending key) |
| Schema | `vector(768)` + HNSW indexes | Applied |
| Embedding | Nomic embed-v2 MoE (:8090) | Running |
| Embed client | `Zdots::AI::EmbedConnection` | Active |
| Chat client | Qwen3-8B + 0.6B spec-draft (:8080) | Running |
| TLS proxy | nginx (`llama.local`, `embed.local`) | Running |

## Constraints

- `ZDOTS_CAPTURE_ENABLED=0` is hard-enforced when `ZDOTS_CONTEXT=work` — capture is never active on work machines
- Chat server (`llama-server :8080`) has `embeddings: false` — this is permanent. `--embeddings` + `--spec-draft-model` crashes llama.cpp. Use the embed server exclusively for all vector generation.
- Embedding dimension is 768 (Nomic v2 MoE). The pgvector schema is already at `vector(768)`. Do not revert to `vector(4096)` without a corresponding migration; HNSW indexes have a 2000-dim limit.
- See `docs/adr/0001-nginx-not-in-ai-query-path.md`: CLI tools (`zdots-ask`, `ai-query`, Ruby pipeline) go direct to loopback endpoints, not through nginx.
