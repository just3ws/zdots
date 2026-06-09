# MLX Implementation Plan: Zdots Orchestrator (`zpi`, `zaider`, `zopencode`)

## Objective
Refactor the Zdots `zpi` (Zdots Platform Interface), `zaider`, and `zopencode` to route inference requests through `mlx-lm` instead of the legacy `llama-server`.

## 1. Technical Requirements
- **Dependency:** Install `mlx-lm` in the local Python environment.
- **Interface Seam:** Refactor `zpi`, `zaider`, and `zopencode` to provide an abstraction over inference providers (`provider: 'llama-cpp' | 'mlx'`).
- **Configuration:** Update `etc/ai-models.yaml` to include MLX-specific paths.

## 2. Implementation Steps
### Phase 1: The MLX Wrapper
- [ ] Create `lib/inference/mlx_engine.py`: A thin wrapper around `mlx_lm.load` and `generate`.
- [ ] Implement a standardized `generate_completion()` method that mimics the existing API.

### Phase 2: Interface Integration
- [ ] Modify `zpi`, `zaider`, and `zopencode` to detect the `ZDOTS_INFERENCE_ENGINE` environment variable.
- [ ] Route requests based on engine selection.
- [ ] Implement graceful fallback (if MLX fails, alert and potentially fall back to `llama-server`).

### Phase 3: Validation
- [ ] Run the existing integration tests against the new MLX engine.
- [ ] Measure latency improvement vs baseline (`inference_report.md`).

## 3. Risks
- **Model Compatibility:** Ensuring all GGUF models are compatible with MLX converter.
- **Resource Contention:** Ensuring MLX does not collide with existing `llama-server` processes if they are left running.
