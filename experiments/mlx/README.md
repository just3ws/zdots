# experiments/mlx — Apple MLX inference (archived)

Archived 2026-06-14. Preserved for future analysis; **not active, not on `PATH`**.

## Why archived

llama.cpp is the **primary local LLM backend**. Emerging Apple-Silicon-native
inference will arrive through **apfel** (Apple Intelligence) as that capability
matures — not through this MLX prototype. The harnesses (Pi, Aider, OpenCode) sit
in front of llama.cpp; the backing infrastructure stays llama.cpp + the emerging
Apple-native path. This experiment was in the way of that work, so it was contained
here (the same treatment as `experiments/zsynod/`).

## Contents (extracted from active tree)

| File | Was | Notes |
|---|---|---|
| `zdots-mlx-prepare` | `bin/zdots-mlx-prepare` | HF→MLX model conversion CLI (needs `mlx_lm`) |
| `mlx_engine.py` | `lib/inference/mlx_engine.py` | MLX completion engine |
| `gateway.py` | `lib/inference/gateway.py` | engine gateway (imported `inference.mlx_engine`) |
| `inspect_mlx.py`, `inspect_mlx_stream.py` | repo root | scratch probes |
| `mlx_benchmark_20260609_195045.json` | repo root | one benchmark run |
| `mlx_help.txt` | repo root | captured help output |

## What changed in the active tree

- `bin/ai-query` dropped its `ZDOTS_INFERENCE_ENGINE=mlx` branch — it is now
  unconditionally llama.cpp (`aiq_submit`). The `ZDOTS_INFERENCE_ENGINE` env var is
  retired.
- `lib/inference/` was removed (both modules moved here).

## Reviving (future analysis)

These files import as a flat set, not the original `inference.*` package layout;
restore the package structure under `lib/inference/` if reactivating. Reattach to
`ai-query` behind an explicit, gated engine selector — but only after a deliberate
decision to add a second backend alongside llama.cpp.
