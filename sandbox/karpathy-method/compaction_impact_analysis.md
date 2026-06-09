# Context Compaction Impact & Test Analysis

## 1. Impacted Tooling Inventory
Integrating `context-compact` is not limited to `zpi`. It must be implemented at the **Inference Gateway** level—the common interface that *all* agents use to speak to the local `llama-server`.

| Tool | Role | Impact |
| :--- | :--- | :--- |
| **`providers/tools/aider.zsh` (Zaider)** | Agentic Codebase Tool | **High**. Aider has massive context bloat. Needs integration to compact session history. |
| **`providers/tools/opencode.zsh` (Zopencode)** | Code Assistant | **High**. Similar to Aider, needs a compact L2/L3 memory model. |
| **`bin/ai-query`** | One-shot Inference | **Low/Med**. Needs compaction for RAG payloads (PI Context hydration). |
| **`bin/zdots-worker`** | Background Agent | **High**. Background jobs run continuously—compaction is mandatory to prevent memory leak over time. |

## 2. Robust Test Harness (`test_compaction_robust.py`)
To ensure robustness, I am upgrading our testing suite to cover these scenarios:
1.  **Needle Retention:** Ensure high-importance turns are NEVER pruned.
2.  **Budget Enforcement:** Ensure total turn token count stays < 1024.
3.  **Graceful Degradation:** Ensure standard history (no importance flag) is pruned correctly.
4.  **JSON Robustness:** Ensure the tool handles invalid input gracefully.

## 3. Plan for Implementation
1.  **Refactor Test Suite:** Enhance the test harness to simulate these scenarios.
2.  **Gateway Integration:** Introduce `context-compact` into the shared library (`lib/inference/gateway.bash` or equivalent) that `aider.zsh` and `opencode.zsh` use, rather than patching them individually.
3.  **Validate:** Verify throughput and stability.
