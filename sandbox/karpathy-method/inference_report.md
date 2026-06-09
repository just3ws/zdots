# Inference Performance Update (As of 2026-06-09)

## Regression Findings (Iteration 1.1)
- **Experiment:** Increased `batch_size`/`ubatch_size` from 2048 to 4096.
- **Outcome:** **Regression.** Latency increased significantly across all token counts (e.g., 1024 tokens went from ~6.5s to ~15.3s).
- **Hypothesis:** Increased memory footprint for the 4096 batch buffer likely triggered aggressive OS swap or kernel-level memory management overhead, neutralizing any throughput gains from increased parallelism.
- **Conclusion:** 2048 is the current stability/performance optimum for this hardware/model configuration.
