# experiments/mlx — Apple MLX inference (archived)

Archived 2026-06-14. Preserved for future analysis; **not active, not on `PATH`**.

## Why archived

llama.cpp is the **primary local LLM backend**. Emerging Apple-Silicon-native
inference runs through Apple's own `fm` CLI (Apple Intelligence; see
`providers/tools/apple-fm.zsh`) — not through this MLX prototype. The harnesses (Pi, Aider, OpenCode) sit
in front of llama.cpp; the backing infrastructure stays llama.cpp + the emerging
Apple-native path. This experiment was in the way of that work, so it was contained
here for historical reference.

## Contents (extracted from active tree)

| File | Was | Notes |
|---|---|---|
| `zdots-mlx-prepare` | `bin/zdots-mlx-prepare` | HF→MLX model conversion CLI (needs `mlx_lm`) |
| `mlx_engine.py` | `lib/inference/mlx_engine.py` | MLX completion engine |
| `gateway.py` | `lib/inference/gateway.py` | engine gateway (imported `inference.mlx_engine`) |
| `inspect_mlx.py`, `inspect_mlx_stream.py` | repo root | scratch probes |
| `mlx_benchmark_20260609_195045.json` | repo root | one benchmark run |
| `mlx_help.txt` | repo root | captured help output |
| `karpathy_method/` and `tests/` | experiment-only compaction helper and its test |

## What changed in the active tree

- `bin/ai-query` dropped its `ZDOTS_INFERENCE_ENGINE=mlx` branch — it is now
  unconditionally llama.cpp (`aiq_submit`). The `ZDOTS_INFERENCE_ENGINE` env var is
  retired.
- `lib/inference/` and `lib/karpathy_method/` were removed from the active tree;
  their experiment-only copies live here.

## Reviving (future analysis)

This experiment is not part of runtime or CI. To inspect it, run its helper test
from this directory with `python3 tests/test_context_compaction.py`. Reattach to
`ai-query` only after a deliberate decision to add a second backend alongside
llama.cpp; treat the archived benchmark and tuning notes as historical evidence.
