# Inference Performance Results (As of 2026-06-09)

## Experimental Data
| Context Size (Tokens) | Latency (ms) |
| :--- | :--- |
| 512 | 456 |
| 1024 | 4110 |
| 2048 | 8178 |
| 4096 | 18184 |

## Insights
1. **The Threshold Wall:** We observed a massive, non-linear jump in latency when transitioning from 512 to 1024 tokens (a ~9x increase). This strongly suggests a memory-management threshold (swap invocation or VRAM cache limitation) on the M-series Mac.
2. **"Prompt Tax" Quantified:** Beyond the 1024-token mark, latency increases at roughly ~4.5ms per token (~220 tokens/sec processing), but the initial jump indicates we should aggressively cap our context window *well below 1024 tokens* for high-frequency agentic tasks.
3. **Implication:** Our "Context-as-Memory" strategy is not just optimization; it is a **hard performance requirement**. Any agent turn exceeding ~1024 tokens will be perceived as "hang" time by the user.
