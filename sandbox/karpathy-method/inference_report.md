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
