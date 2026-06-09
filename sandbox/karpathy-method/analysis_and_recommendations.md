# Analysis & Recommendations Report: Zdots Inference Optimization

## 1. Executive Summary
Zdots performance is currently bottlenecked by an inference "Prompt Tax" and memory pressure on macOS. The system hits a non-linear latency wall at 1024 tokens. To achieve meaningful, agentic work, we must shift from a "Chat" paradigm to **Atomic State-Machine Orchestration** using the **MLX** framework.

## 2. Key Findings
- **The Threshold:** Performance degrades by ~9x when exceeding 1024 tokens.
- **The Cause:** KV cache memory pressure leading to swapping on M-series unified memory.
- **The Constraint:** Our current inference pipeline is optimized for stability, not throughput.

## 3. Strategic Recommendations
### A. Infrastructure: MLX Transition
*   **Recommendation:** Adopt `mlx-lm` as the core inference kernel.
*   **Rationale:** Native Apple Silicon memory management (lazy loading, zero-copy `mmap`) is essential for avoiding swapping and enabling rapid model load/unload cycles.

### B. Architecture: Agentic Atomicity
*   **Recommendation:** Enforce a hard 1024-token budget per agent turn.
*   **Rationale:** Granular turns prevent memory bloat and force "State-Machine" behavior, increasing the reliability of agentic tool calls.

### C. Implementation Roadmap (Next Phase)
1.  **MLX Migration:** Implement a wrapper in `zpi` to route inference requests through `mlx-lm` instead of the legacy `llama-server`.
2.  **Token Budgeting:** Introduce a `ZDOTS_MAX_TOKENS` environment variable across `zpi`, `zaider`, and `zopencode` to hard-limit context window consumption.
3.  **Proactive Compaction:** Build a reusable `bin/context-compact` utility that summarizes conversational history into a fixed L1/L2 memory structure before every LLM interaction.

## 4. Next Steps
- [ ] Transition `zpi` to MLX backend.
- [ ] Audit `zaider` and `zopencode` for context-bloat vectors.
- [ ] Pilot the `context-compact` utility in the `zpi` workflow.
