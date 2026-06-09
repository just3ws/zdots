# Performance Tuning Manifesto: Zdots Inference

## 1. Safety & Reversibility Mandate (CRITICAL)
**Any system-level modification (sysctl, network config, kernel parameters) MUST have a documented, automated, and tested reversal path.**

*   **Temporary vs. Persistent:**
    *   `sysctl` (temporary): Changes are lost on reboot. To revert, reboot.
    *   `sudo sysctl -w variable=default_value`: Immediate runtime reversal.
*   **Verification:** Before applying, record the current system state (`sysctl -a | grep <variable> > backup.txt`).
*   **The "Undo" Utility:** All automated performance scripts must include an `--undo` flag that restores the backup state.

## 2. Tuning Strategy (Apple Silicon)
1. **Memory:** Increase `iogpu.wired_limit_mb` (Temporary, reversible via reboot or explicit command).
2. **Inference:** KV Cache quantization and Flash Attention (Zero impact on system stability).
3. **Orchestration:** MLX-based engine (Application-level, no system-level side effects).

## 3. Implementation Proposal: The `perf-tune.sh` Utility
We will build a utility that manages these changes:
- `perf-tune.sh apply` -> Captures baseline, applies tuning, logs to `logs/perf.log`.
- `perf-tune.sh undo` -> Restores baseline from capture.
