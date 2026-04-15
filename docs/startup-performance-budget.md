---
id: startup-performance-budget
title: "Startup Performance Budget"
purpose: Documents shell startup time targets and profiling methodology.
links:
  - id: zsh-quality-rubric
    rel: related
  - id: readme
    rel: parent
---

# Startup Performance Budget

Assessed on: 2026-03-02

## Budget

- Metric: median `real` startup time for `zsh -i -c exit`
- Sampling: 5 runs (`make bench` or `ZDOTS_CHECK_REPORT_STARTUP=1 ./bin/check`)
- Warning threshold (non-blocking): `0.08s`

## Current Baseline

Recorded from `make bench`:

| Run | Real (s) |
| --- | ---: |
| 1 | 0.04 |
| 2 | 0.03 |
| 3 | 0.03 |
| 4 | 0.03 |
| 5 | 0.03 |

Median baseline: **0.03s**

## Policy

1. Treat startup timing as a quality signal, not a hard blocker.
2. Keep `bin/check` timing report non-blocking (warning-only) to avoid flaky CI failures.
3. Re-baseline when prompt/plugins or startup modules change materially.
4. Refresh baseline at least once per quarter or after major environment changes.

## CI Integration

- Startup timing report is enabled in CI via `ZDOTS_CHECK_REPORT_STARTUP=1`.
- Warning threshold can be tuned with `ZDOTS_STARTUP_WARN_THRESHOLD_SEC`.
