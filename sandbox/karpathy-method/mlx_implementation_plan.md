# MLX Implementation Plan: Zdots Orchestrator (Updated)

## 1. Identified Gap: Model Format
- **Finding:** `mlx-lm` does not natively support GGUF files (the current standard for `llama.cpp`).
- **Required Action:**
    - Download native MLX-format models from HuggingFace (e.g., `mlx-community/Qwen2.5-7B-Instruct-4bit`) 
    - OR use `mlx_lm.convert` to convert the existing GGUF models.

## 2. Updated Implementation Roadmap
1. **Model Preparation:**
   - [ ] Implement `bin/zdots-mlx-convert` to convert GGUF to MLX (or fetch MLX-native).
2. **MLX Engine Wrapper:**
   - [ ] Update `lib/inference/mlx_engine.py` to handle MLX-native directory paths.
3. **Gateway Integration:**
   - [ ] Finalize `ai-query` routing logic to handle path resolution for MLX models.
4. **Validation:**
   - [ ] Validate throughput improvement.
