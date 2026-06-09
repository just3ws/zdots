# Final Research Report: Zdots Inference & Agentic Strategy

## 1. The Inference Bottleneck (Observed)
- **Constraint:** The 1024-token barrier is a hard performance wall for our hardware. Exceeding this triggers non-linear latency jumps (~400ms to >4s).
- **Architecture Shift:** Agentic workflows must abandon "chat" patterns in favor of **Agentic Atomicity**—breaking complex tasks into granular, 500-1000 token state transitions.

## 2. Recommendation: MLX Framework
To maximize throughput and minimize memory pressure on Apple Silicon:
- **Immediate Action:** Transition inference backend to **MLX**.
- **Rationale:** 
    - Native Apple Silicon optimization (Metal).
    - "Lazy Loading" reduces initial model-load overhead.
    - Zero-copy weight access using `mmap` and `safetensors`.
- **Implementation:** Utilize `mlx-lm` for local model orchestration.

## 3. The "Mere Mortal" Agent Architecture (The Plan)
We are adopting a **State-Machine Orchestration** layer rather than a Chat layer:
1. **Atomic Turns:** Each LLM interaction is constrained to <1024 tokens.
2. **Context Compaction:** Every agent turn *must* result in a compacted state summary (L1/L2 memory).
3. **Explicit Tooling:** Force the agent to use tool calls for retrieval (L4 -> L3) rather than loading everything into the prompt (Context Window).

## 4. Next Step
Implement the **MLX-native orchestrator** to enforce the 1024-token budget programmatically.
