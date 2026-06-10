# Strategic Decision Record: Inference Strategy Pivot

## 1. Decision: Retain Current Engine, Focus on Architecture
**Choice:** We will NOT migrate to `vLLM` or `oMLX` at this time.
**Rationale:** While these engines offer superior throughput for concurrent/multi-user scenarios, the integration debt—refactoring the Zdots CLI-based inference gateways—is too high. Our current goal is to stabilize an "AI OS" for the *individual developer* on macOS, not to build a multi-tenant serving platform.

## 2. Refined Roadmap: The "Core" Constraints
We have confirmed that memory pressure and context latency are our true bottlenecks. We will solve these within the existing framework:

### Path A: Architectural Compaction (Context-as-Memory)
- **Goal:** Hard limit every agent turn to <1024 tokens.
- **Implementation:** Complete the `context-compact` integration into the `zpi` gateway.
- **Risk:** Zero.

### Path B: Low-Level Tensor Hacking ("Hard Mode")
- **Goal:** Optimize the MLX-based forward pass for memory efficiency without altering the engine architecture.
- **Implementation:** Explore KV cache compression techniques directly within the `MLXEngine` (e.g., custom quantization of KV tensors).
- **Risk:** Medium-High. Requires rigorous testing harness to prevent "gibberish" output.

## 3. Immediate Next Action
Proceed with **Path A (Context Compaction)**. We will integrate `context-compact` into the `zpi` gateway to ensure every agent turn is forced into "Atomic State" mode, effectively bypassing the memory pressure wall without needing an engine rewrite.
