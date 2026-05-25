# RAG Activation Guide

This document covers the exact steps to activate the RAG pipeline once the prerequisites are met.

## Current State

RAG is **not active**. Two blockers:

1. `ZDOTS_CAPTURE_ENABLED=0` — capture requires the encryption key (see below)
2. No dedicated embedding server — the chat server (`llama-server` on :8080) has `embeddings: false`
   because `--embeddings` + `--spec-draft-model` causes a llama.cpp crash loop

## Blocker 1: Encryption Key

The DB encryption key must come from macOS Keychain. **Never** in `.zdots.env`, `.zdots.local`, or any tracked file.

```bash
# Provision the key (one-time setup — generates a random 32-byte key)
security add-generic-password \
  -a "$USER" \
  -s "ZDOTS_DB_ENCRYPTION_KEY" \
  -w "$(openssl rand -hex 32)" \
  -T "" \
  /Users/$USER/Library/Keychains/login.keychain-db

# Verify retrieval
security find-generic-password -a "$USER" -s "ZDOTS_DB_ENCRYPTION_KEY" -w
```

Then add to `.zdots.local` (NOT `.zdots.env`):
```bash
export ZDOTS_DB_ENCRYPTION_KEY=$(
  security find-generic-password -a "$USER" -s "ZDOTS_DB_ENCRYPTION_KEY" -w 2>/dev/null
)
```

Once set, enable capture:
```bash
export ZDOTS_CAPTURE_ENABLED=1  # in .zdots.local
```

## Blocker 2: Dedicated Embedding Server

The chat server cannot run embeddings with speculative decoding active. The correct architecture is two servers:

| Server | Port | Model | Purpose |
|--------|------|-------|---------|
| Chat (current) | 8080 | Qwen3-8B Q4_K_M | `/v1/chat/completions` — all AI interaction |
| Embed (new) | 8090 | Nomic embed-v2 MoE Q8_0 | `/v1/embeddings` — RAG vector generation |

The embedding model (`nomic-embed-text-v2-moe.Q8_0.gguf`) is already in `etc/ai-models.yaml` as profile `embed` (0.52GB). It's small enough to run alongside the chat server.

### Embedding server setup

```bash
# 1. Download the embedding model
ZDOTS_AI_PROFILE=embed llama-ctl model-download

# 2. Start a standalone embedding server on port 8090
# (until a second plist is created, run manually)
/opt/homebrew/bin/llama-server \
  --host 127.0.0.1 \
  --port 8090 \
  --model ~/.local/share/llama-cpp/models/nomic-embed-text-v2-moe.Q8_0.gguf \
  --ctx-size 512 \
  --n-gpu-layers 99 \
  --embeddings \
  --pooling mean \
  --batch-size 2048 \
  --ubatch-size 2048 \
  --alias embed \
  --no-warmup \
  --log-disable &

# 3. Verify embeddings endpoint
curl -s -X POST http://127.0.0.1:8090/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"embed","input":"zdots shell configuration"}' | jq '.data[0].embedding | length'
# → 768 (Nomic v2 MoE dimension)
```

### Point ZDOTS_AI_EMBED_ENDPOINT

Add to `.zdots.local`:
```bash
export ZDOTS_AI_EMBED_ENDPOINT="http://127.0.0.1:8090"
```

The context-engine (`zdots-ctx`) will use this endpoint for embedding generation once `ZDOTS_CAPTURE_ENABLED=1`.

### Future: second launchd plist

Create `com.zdots.llama-embed.plist` following the same pattern as `com.zdots.llama-server.plist` but:
- Port 8090
- Profile `embed`
- `--embeddings --pooling mean` (safe without speculative decoding)
- No `--spec-draft-model`
- Lighter config (no flash-attn, parallel 1)

This is a backlog task: `llama-ctl` should support a second profile-driven plist for embedding servers.

## Activation Checklist

- [ ] Encryption key provisioned in Keychain
- [ ] `ZDOTS_DB_ENCRYPTION_KEY` exported in `.zdots.local`
- [ ] Embedding server running on :8090
- [ ] `ZDOTS_AI_EMBED_ENDPOINT=http://127.0.0.1:8090` in `.zdots.local`
- [ ] `ZDOTS_CAPTURE_ENABLED=1` in `.zdots.local`
- [ ] Run `zdots-ctx migrate` to verify schema is current
- [ ] Test: `zdots-ctx capture` on a real session and verify `zdots-ctx list`

## Notes

- `ZDOTS_CAPTURE_ENABLED=0` is enforced in `ZDOTS_CONTEXT=work` — never enable capture on work machines
- Embedding dimension: Nomic v2 MoE uses 768 dimensions. The current pgvector schema uses 4096 (Qwen3-8B). If switching to Nomic for embeddings, a migration to `vector(768)` will be required.
- The `docs/ai-pipeline-seams.md` Seam 7 documents the pgvector schema invariant.
