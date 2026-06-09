# Context Engineering: Managing Memory Pressure

## 1. The Reality: Context Window as RAM
In a resource-constrained Mac (Apple Silicon), the context window is not "infinite"; it is the primary source of memory pressure.
- **Problem:** Every token in the prompt consumes KV cache (VRAM/RAM). Large context = model swapping = massive latency.
- **The Constraint:** We are limited by the available unified memory. Exceeding this limit kills inference performance.

## 2. The Strategy: "Memory-First" Context Management
We must shift from "RAG as dump" to "RAG as selective swap."

### A. Hierarchical Context (The Memory Hierarchy)
| Layer | Storage | Persistence | Purpose |
| :--- | :--- | :--- | :--- |
| **L1 (Registers)** | System Prompt (curated) | Permanent | Persona, core constraints, state. |
| **L2 (Cache)** | Task Summary (compacted) | Session-bound | Current reasoning objective. |
| **L3 (RAM)** | Relevant Tool Output | Transient | Immediate tool results for next action. |
| **L4 (Disk)** | Full Knowledge Vault | Long-term | Retrieval source for L3. |

### B. Proactive Compaction (The GC)
We must treat context like a garbage-collected system.
- **Compaction:** Before a new agent turn, run a "summarize and prune" function to shrink L3 into L2.
- **Pruning:** Drop L3 data immediately after use.
- **Budgeting:** Never exceed a pre-defined "context budget" (e.g., 2000 tokens for the prompt).

## 3. Implementation Proposal
1. **Define Budget:** Set a hard `MAX_PROMPT_TOKENS`.
2. **Implement `compact_context.sh`:** A lightweight tool that takes `context.json`, summarizes the content to fit within budget, and outputs a refined context.
3. **Instrumentation:** Monitor `llama-server` memory pressure logs to validate that this strategy reduces swap usage.
