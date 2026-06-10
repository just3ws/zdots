# Inference Performance Update (As of 2026-06-09)

## 1. Inference Engine Comparison: llama-cpp (Optimized) vs. MLX (Default)
- **Baseline:** Optimized `llama-cpp` (Flash Attention, 8-bit KV Quantization, 2048 Batch Size).
- **MLX Engine:** Default `mlx_lm` configuration.
- **Result:** **Regression.** The default MLX implementation is significantly slower than our highly-tuned `llama-cpp` baseline (e.g., 512-token turns are ~80% slower).
- **Conclusion:** MLX is not a "magic bullet." Without applying equivalent performance tuning (KV quantization, native Metal kernel parameters), it performs worse than the mature `llama.cpp` pipeline.

## 2. Next Ratchet: MLX Optimization
To beat the `llama-cpp` baseline, we must tune MLX:
1. **Quantization:** Enable 4-bit/8-bit KV cache quantization in MLX.
2. **Flash Attention:** Verify MLX is utilizing hardware-native attention kernels (it should be default, but requires validation).
3. **Batching:** Explicitly control batch sizes if possible via `mlx_lm` kwargs.

## 3. Plan
- [ ] Implement `context_compaction` in `mlx_engine.py` (mandatory requirement).
- [ ] Re-run benchmark with KV cache quantization enabled in MLX.
# Tuning Retrospective: Context Window Capping (8192)

## 1. Experiment Overview
- **Objective:** Reduce memory pressure and improve latency by capping `ctx_size` to 8192.
- **Hypothesis:** Lowering the pre-allocated KV cache would reduce overhead for smaller turns.
- **Outcome:** **Regression.** Latency increased significantly for small context sizes.

## 2. Deep-Dive Findings
- **The "Efficiency Wall":** Our performance tuning for `llama.cpp` has reached a plateau. Simple configuration tweaks (batch size, context size) are not sufficient because the overhead of `llama.cpp`'s memory management on Apple Silicon is already tightly optimized in our Golden Baseline.
- **Key Takeaway:** The "1024-token barrier" is an architectural property of our specific workload/hardware, not just a configuration artifact. It cannot be "tuned away" with flags; it must be engineered around (via Compaction) or bypassed (via a different inference backend).

## 3. Implications for Future Optimization
- **Do not chase performance via configuration tweaks:** We have reached the limits of `llama-server` flag optimization.
- **Pivot to Architectural Change:** All future gains must come from changing *how* we interact with the model (Context Compaction) or *what* we use to infer (MLX).
# Reality vs. Authoritative Mapping: Zdots vs. Karpathy Principles

This document bridges the "ground truth" of the Zdots platform against the primary-source principles defined in `authoritative_resources.md`.

## 1. The Core Architectures

| Concept | Karpathy Stance | Zdots Reality | The Bridge (Recommendation) |
| :--- | :--- | :--- | :--- |
| **Ratchet Loops** | Autonomous git-revert loops. | Manual `git` + manual validation. | Implement `bin/ratchet` for `zdots-ruby-bump`. |
| **"Source Code"** | Labeled datasets / Rules. | Code/Scripts (Software 1.0). | Treat `.pi` and `etc/prompts/` as curatable datasets. |
| **Orchestration** | 3-file rigid seam structure. | Distributed, service-based (bin/services). | Standardize agents to 3-file structure (`program.md`, `immutable.py`, `mutable.py`). |
| **Context** | Context-as-RAM (Compaction). | RAG (Retrieval + Dump). | Implement `compact_context.sh` (L1/L2 memory). |

## 2. Gap Identification

### Gap 1: Autonomous Engineering (The Ratchet)
*   **Reality:** We rely on human-in-the-loop (HITL) for validation. 
*   **Conflict:** This limits throughput to human cognitive speed, violating the "Maximize Token Throughput" principle.
*   **Fix:** Build a `git-ratchet` harness that automates the `experiment -> test -> commit/revert` cycle.

### Gap 2: Context Management (The "Prompt Tax")
*   **Reality:** We ingest data into a RAG pipeline and treat the context window as a dumping ground.
*   **Conflict:** We hit the 1024-token wall, causing 9x latency jumps.
*   **Fix:** Implement the L1/L2/L3 memory hierarchy. Move from retrieval-by-similarity (vector) to retrieval-by-reasoning (state).

### Gap 3: Tooling Logic (API Glue vs. Logic)
*   **Reality:** `zdots` uses complex shell/ruby scripts (`bin/`).
*   **Conflict:** Logic is buried in deterministic code; LLMs are treated as external callers.
*   **Fix:** Re-expose `bin/` scripts as agentic tools (using the MCP or Zdots CLI Bridge) so they are discoverable *by the agents* as system calls.

## 3. Immediate Action Plan
1.  **Orchestrator Seam:** Refactor `zpi` to provide a standard interface for "Atomic Turns."
2.  **Experiment:** Execute the first Ratchet Loop on `zdots-ruby-bump`.
3.  **Compaction:** Develop the `compact-context` tool for L1/L2 memory management.
