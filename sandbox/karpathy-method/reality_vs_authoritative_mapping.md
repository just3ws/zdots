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
