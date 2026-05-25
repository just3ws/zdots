# AI Learning Map

Curated research resources for each capability gap in the local AI stack.
Each section maps a specific gap to the 2-3 most useful resources to go deeper.

---

## 1. RAG Pipeline (Retrieval-Augmented Generation)

**Gap**: `ZDOTS_CAPTURE_ENABLED=0` — RAG is dark pending encryption key + dual embed server.

**Key concepts**: embedding vectors, cosine similarity, chunking strategies, hybrid search (BM25 + semantic).

**Resources**:
- [pgvector docs](https://github.com/pgvector/pgvector) — operators (`<=>`, `<#>`, `<+>`), index types (IVFFLAT vs HNSW), distance metrics. Focus on HNSW for production (better recall, faster query).
- [Nomic Embed v2 Model Card](https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe) — the embedding model already in `etc/ai-models.yaml`. Note the 768-dimension output vs Qwen3-8B's 4096.
- [llama.cpp embeddings docs](https://github.com/ggml-org/llama.cpp/tree/master/examples/embedding) — `--embeddings --pooling mean` semantics, batch size constraints (why ubatch_size must match embedding input length).

**Activation path**: see `docs/rag-activation.md`.

---

## 2. Qwen3 Thinking Mode

**Gap**: No `--think` flag on `zdots-ask` (now implemented). No UI path to inspect reasoning.

**Key concepts**: chain-of-thought (CoT) prompting, extended thinking, `/think` vs `/no_think` control tokens, thinking budget.

**Resources**:
- [Qwen3 Technical Report](https://arxiv.org/abs/2505.09388) — Section 4 covers the hybrid thinking/non-thinking architecture. Explains when thinking helps (math, multi-step reasoning) vs hurts (direct lookup, speed-critical queries).
- [Qwen3 Blog Post](https://qwenlm.github.io/blog/qwen3/) — practical guidance on `enable_thinking` API parameter and the `/think` token. Key insight: `/no_think` at start of user turn suppresses thinking; `/think` enables it mid-conversation.
- Anthropic Extended Thinking docs (for Claude) — different implementation but same conceptual tradeoffs apply. Useful mental model for when to budget reasoning tokens.

**Usage in zdots**:
```bash
zdots-ask --think "write a Sequel migration to add compound index on (user_id, created_at)"
ai-query --think --mode raw "walk through this bash function for correctness"
```

---

## 3. Speculative Decoding

**Gap**: Draft model configured but performance is bottlenecked by system memory pressure.

**Key concepts**: speculative sampling, token acceptance rate, draft-target model compatibility, MTP (Multi-Token Prediction).

**Resources**:
- [Speculative Sampling (DeepMind 2023)](https://arxiv.org/abs/2302.01318) — the original paper. Explains the statistical guarantee that speculative decoding is lossless (same distribution as the target model). Small models can predict 1-5 tokens that the big model accepts if they share the same tokenizer/vocab.
- [llama.cpp speculative docs](https://github.com/ggml-org/llama.cpp/tree/master/examples/speculative) — `--draft-model`, `--draft-max-tokens`, practical guidance on matching draft to target model family.
- [MTP Guide (Unsloth)](https://unsloth.ai/docs/models/qwen3.6#mtp-guide) — covers the newer MTP approach where draft heads are baked INTO the model weights. Not available for the current Qwen3-8B GGUF but useful context for future model selection.

**Performance note**: Expected 15-30 tok/s on M4 with GPU offload. If seeing <5 tok/s, check system memory: `vm_stat | grep "Pages free"`. Free pages < 50,000 (~200MB) indicates memory pressure causing swap. Kill memory-intensive processes or reboot.

---

## 4. Temperature Tuning

**Gap**: `temperature: 0.4` is a reasonable default but not validated against task types.

**Key concepts**: temperature, top-p, top-k, min-p, repetition penalty, sampling strategies.

**Resources**:
- [LLM Sampling Parameters Guide (Hugging Face)](https://huggingface.co/blog/how-to-generate) — practical explanation of temperature, top-p, and beam search. Key: temperature=0 is deterministic (greedy); temperature=1 is the model's trained distribution; below 0.7 sharpens focus, above 1.2 increases creativity.
- [min-p sampling paper](https://arxiv.org/abs/2407.01082) — newer alternative to top-p. Often better quality. llama.cpp supports it via `--min-p N`.

**Recommended per-task settings**:
| Task | Temperature | Why |
|------|-------------|-----|
| Code generation | 0.2–0.4 | Deterministic, prefer correct over creative |
| Shell scripting | 0.3 | Low variance preferred |
| Summarization/analysis | 0.4–0.6 | Some flexibility useful |
| Thinking mode | 0.6 | Diversity in reasoning traces improves coverage |

---

## 5. Unlimited Generation (n_predict: -1)

**Gap**: Previously capped at 2048. Now unlimited. Monitor for context exhaustion.

**Key concepts**: context window, KV cache eviction, sliding window attention.

**Resources**:
- [llama.cpp context management](https://github.com/ggml-org/llama.cpp/blob/master/docs/development/token-generation-performance-tips.md) — how the KV cache fills and what happens at the limit. Key: once ctx_size tokens are consumed, older tokens are evicted (sliding window or truncation), which degrades coherence.
- Qwen3-8B context: 32768 tokens training context (128K with YaRN extended). The current server uses 32768 total (16384 per slot). For long generation, watch for `n_ctx_seq` warnings in the log.

---

## 6. Context Window Optimization

**Gap**: Running at 16384 tokens/slot (half the training context of 32768). Trade-off: more context = more memory.

**Key concepts**: YaRN (extended context), rope_scaling, KV cache quantization.

**Resources**:
- [YaRN paper](https://arxiv.org/abs/2309.00071) — how RoPE scaling extends context beyond training length. Qwen3-8B supports up to 128K tokens via YaRN (`--rope-scale` in llama.cpp) but requires proportionally more KV memory.
- [KV cache quantization guide](https://github.com/ggml-org/llama.cpp/wiki/Feature:-k,v-cache-quantization) — `q8_0` (current) vs `q4_0` vs `f16`. q8_0 halves memory vs f16 with minimal quality loss. q4_0 halves again with more quality loss.

**M4 16GB budget calculation**:
```
Model weights:   5.0 GB (Qwen3-8B Q4_K_M)
Draft weights:   0.4 GB (Qwen3-0.6B Q4_K_M)
KV cache:        ctx × n_kv_heads × head_dim × 2 × q8_bytes × slots
                = 16384 × 4 × 128 × 2 × 1 × 2 ÷ 1e9 ≈ 0.27 GB
OS + apps:       ~4–6 GB
Total:           ~10–12 GB → safe within 16 GB
```

---

## 7. Embedding Model Architecture

**Gap**: Using the wrong model for embeddings (chat model ≠ embedding model). Dedicated embedding server needed.

**Key concepts**: bi-encoder vs cross-encoder, matryoshka embeddings, MTEB benchmarks.

**Resources**:
- [MTEB Leaderboard](https://huggingface.co/spaces/mteb/leaderboard) — benchmark for embedding models. Nomic v2 MoE is top-tier for local models. Filter by "retrieval" task type and model size < 1GB.
- [Nomic Embed v2 MoE](https://huggingface.co/nomic-ai/nomic-embed-text-v2-moe) — the model in `etc/ai-models.yaml`. Key detail: 768-dim output (not 4096), uses MoE architecture for quality/speed, Apache 2.0 license.
- [Matryoshka embeddings](https://arxiv.org/abs/2205.13147) — nested embeddings that allow trading dimension for speed without retraining. Some models support this; check if Nomic v2 does (it does via `truncate_dim`).

---

## 8. Eval Suite Design

**Gap**: No quantitative baseline for model comparison. Tests are property-based (does it work?) not quality-based (how well?).

**Key concepts**: MMLU, HumanEval, perplexity, TruthfulQA, domain-specific evals.

**Resources**:
- [LMSYS Chatbot Arena](https://chat.lmsys.org/) — the practical standard for "which model wins." Elo-ranked human preference comparisons. Use as a reference for expected relative performance.
- [EleutherAI LM Evaluation Harness](https://github.com/EleutherAI/lm-evaluation-harness) — programmatic eval across 200+ tasks. Can evaluate local llama.cpp models via the OpenAI-compatible API. Run against Qwen3-8B to get MMLU/HellaSwag baselines.
- [Ollama eval approach](https://github.com/ollama/ollama/tree/main/integration) — simpler: 10 golden prompt/response pairs with string matching. Practical alternative to full harnesses for regression detection.

**Zdots-specific eval ideas**:
- Shell command accuracy: "list files modified in last 24h" → expect `find . -mtime -1`
- Domain routing: 20 prompts → verify domain assignment matches expected
- PHI scrubbing: 10 prompts with SSN/MRN → verify zero leakage
- Response latency: track p50/p95 tokens/second over time

---

## 9. Distillation Prompt Engineering

**Gap**: Distillation prompt was a free-form example. Now has explicit schema (see `bin/zdots-ctx`).

**Key concepts**: structured output, constrained decoding, JSON mode, grammar-based sampling.

**Resources**:
- [llama.cpp grammar-based sampling](https://github.com/ggml-org/llama.cpp/tree/master/grammars) — `--grammar-file` flag enforces BNF grammar constraints on output tokens. Can enforce JSON Schema compliance at the token level (zero hallucinated fields). More reliable than prompt-only schemas.
- [Instructor library](https://github.com/jxnl/instructor) — Python library that uses constrained decoding to enforce Pydantic schemas on LLM output. Works with OpenAI-compatible APIs including llama.cpp.
- [Outlines](https://github.com/outlines-dev/outlines) — similar to Instructor but framework-agnostic. Key insight: Structured generation is always better than post-hoc parsing — failures are caught at generation time, not after.

**Next improvement**: add `--grammar-file` support to `aiq_submit` for distillation calls. The grammar file would enforce the exact JSON schema defined in `bin/zdots-ctx`.
