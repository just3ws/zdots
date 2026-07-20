# Local Model Bench — evaluation registry

Comparison registry for candidate local models on this hardware, measured with
the same harness before any profile change. `etc/ai-models.yaml` is the
*configuration* registry (what llama-ctl can serve); this file is the
*evaluation* registry (what we measured and decided). One row per trial —
append, don't rewrite history.

## Method (repeat exactly, one model hot at a time)

1. Baseline is whatever profile is live; candidates run swap-style: `zsvc stop llama`,
   candidate on `127.0.0.1:11502`, test, kill, `zsvc start llama`.
2. **Quality**: `ZDOTS_AI_ENDPOINT=http://127.0.0.1:11502 zdots-quiz` (16 cases;
   run twice — single-case flakes are sampling noise, not capability).
3. **Speed**: one `/v1/chat/completions` call, the standard prompt (shell command
   resolution explainer), `max_tokens: 256`, `temperature: 0`; record server
   `timings` (prompt + generation tok/s).
4. **Memory**: `ps -o rss= -p <pid>` after the timed call.
5. **Provenance**: sha256 of the GGUF verified against the HF LFS oid before
   first load. Trial artifacts live in `~/.cache/model-trials/` (delete after).

Hardware context (work): Apple M5 Pro, 24GB unified. Practical ceiling for
model + KV with the platform resident (Postgres, OpenObserve, colima, embed,
Puma): **~13GB**.

## Results

| Date | Model | Quant | File GB | RSS GB | Prompt tok/s | Gen tok/s | zdots-quiz | Runtime | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| 2026-07-15 | Qwen3-8B (baseline) | Q4_K_M | 4.7 | ~5 | 238.5 | 50.2 | 16/16 | brew llama.cpp | active profile |
| 2026-07-16 | Bonsai 27B (Qwen3.6-27B ternary, Prism ML) | Q2_0 g128 (1.71 bpw) | 7.2 | 6.5 | ~95 | 24.0 | 16/16* | **PrismML-Eng/llama.cpp fork** | parity quality, half speed; adoption blocked on fork (see notes) |

\* one sampling flake on the first run; clean 16/16 on re-run.

## Notes per trial

### Bonsai 27B ternary (2026-07-16)

- Ternary-compressed **Qwen3.6-27B** (~54GB FP16 → 7.2GB), Apache-2.0. The only
  currently-runnable member of the Qwen3.6 family on 24GB — the family ships
  only 27B dense / 35B-A3B upstream, both too large at honest quants.
- **Format gotcha**: the HF repo carries several GGUFs; only `Q2_0` (g128) loads
  on their llama.cpp fork. `PQ2_0` is a different packing (ggml type 142 —
  rejected even by the fork's main branch). Stock llama.cpp has no
  `GGML_TYPE_Q2_0/Q1_0` at all.
- Thinking model (Qwen3 template); `ai-query`'s `enable_thinking` toggle and
  `/v1/chat/completions` path worked unmodified. 262K context (hybrid ~75%
  linear attention + 4-bit KV) vs 32K on the current profile — whole-transcript
  distills without map-reduce would be the killer app.
- Quoted ~26 tok/s on M5 Pro matched measurement (24.0).
- **Why not adopted**: quality parity (not superiority) on the harness at half
  the speed, and `llama-ctl` would have to bless a third-party fork binary as a
  Platform Service — maintenance tail + provenance call that belongs to the
  operator. Reopen if ternary kernels land upstream or a Qwen3.6 small-dense
  ships.

## Candidate queue

- **gpt-oss-20b** (MXFP4 ~12.1GB, MoE ~3.6B active, mainline llama.cpp) — trial in progress
- **Gemma 3 12B QAT** (~7–8GB) — different lineage, diversity pick
- **DeepSeek-R1-0528-Qwen3-8B** (~5GB) — reasoning distill at current footprint
- **Phi-4 14B** — STEM niche
- **qwen3-14b** — already staged in `etc/ai-models.yaml` (with 0.6B spec-decode draft)
