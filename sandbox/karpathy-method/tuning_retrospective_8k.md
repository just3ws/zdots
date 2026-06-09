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
