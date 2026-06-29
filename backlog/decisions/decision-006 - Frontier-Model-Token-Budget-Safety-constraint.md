---
id: decision-006
title: Frontier-Model Token-Budget Safety constraint
date: '2026-06-14 18:24'
status: proposed
---
## Context

Frontier-model lanes — Claude Code (`cl`) and the opt-in cloud lanes
(`zaider --hf`, `zpi --or`, `zopencode --gh`; see project_frontier_lanes) — meter
real money and operate under hard session limits and rate limits. Local lanes
(`ai-query`, `zaider`, llama.cpp) are effectively free and self-contained; the
existing AI doctrine (local-first, PHI fail-closed) governs *locality and
leakage*, not *spend and exhaustion*.

There is currently no constraint covering token cost. A frontier session can run
out of its budget mid-task and leave work in an incomplete, unsafe state, or
silently spend past the operator's intended account level. This is the cost-side
analogue of the PHI boundary: a guardrail that must fail safe.

## Decision

Every zdots system that can invoke a **frontier model** is subject to a
**Token-Budget Safety** constraint, parallel to the PHI Operating Mode:

1. **Budget is a first-class input.** A frontier lane must know its session/
   rate/spend headroom before and during a run — not discover exhaustion by
   failing. Headroom is observable (a live signal), not implicit.
2. **Warn before hot, stop before overrun.** The system surfaces escalating
   signals (nominal → warm → hot → critical) and recommends a safe action at the
   boundary: compact, checkpoint, or stop at a recoverable point. The operator is
   never first informed of a limit by a hard failure mid-task.
3. **Spend ceiling fails closed.** Crossing the operator's configured account
   spend level requires an explicit, logged opt-in — the same posture as
   `--allow-private` for visibility and cloud lanes for locality. Default is to
   stop, not to spend.
4. **Every frontier call is metered.** Token/cost/latency per call is captured as
   runtime telemetry (OpenObserve spans) and folded into the Knowledge Layer so
   session efficiency is analyzable over time, not just live.
5. **Local lanes are exempt.** The constraint applies only where spend or hard
   session limits exist. Local inference carries no budget gate.

This constraint is the *requirement*; the tooling that satisfies it is tracked as
a feature request (the Token-Budget Governor) and may be delivered incrementally.
Adding a new frontier lane means wiring it to this constraint, the same way
adding an AI call means wiring it to the PHI Scrubber.

## Consequences

Positive: frontier work becomes plannable; mid-task exhaustion and surprise spend
become design-prevented rather than learned-the-hard-way; cost/efficiency data
feeds the Virtuous Loop (Work → Capture → Curate → Infer → Repeat) so successful
session shapes can be distinguished from wasteful ones.

Negative: each frontier lane carries an integration obligation; live headroom for
Claude Code is only as good as the signals the harness exposes (some figures may
be estimated, and estimates must be labeled as such); a fail-closed spend ceiling
can interrupt work, which must be tunable to avoid false stops.

Related: PHI Operating Mode (AGENTS.md §10) — same fail-closed philosophy applied
to cost instead of leakage; project_frontier_lanes; the Token-Budget Governor
feature task (Z-148).

## Implementation

Delivered incrementally as Z-148 (Token-Budget Governor):

- **`bin/cc-burn`** — 5h rolling-window monitor wrapping `ccusage blocks --offline`
  (reads `~/.claude` transcripts; no network). Computes burn rate, time-to-reset,
  projected usage, cache efficiency, threshold alerts, and a fail-closed ceiling gate
  (`--assert-ceiling`). Modes: human | --json | --quiet | --assert-ceiling | calibrate.
- **`bin/cc-burn-watch`** — periodic LaunchAgent alerter (default 300 s). Reads
  `cc-burn --json`; fires macOS notifications on severity worsening (ok→warn→alert).
  On window-close (warn/alert→ok), records a numeric efficiency lesson in the
  Knowledge Layer via `zdots-ctx add-lesson` (tokens, cost, cache %; no transcript
  content — PHI-safe by construction).
- **`bin/cc-statusline`** — reads the watcher cache; appends burn state to the shell
  statusline at zero per-render cost.
- **Ceiling gate (constraint 3):** `zclaude` calls `cc-burn --assert-ceiling` before
  any attended launch. Exit 1 (warn) is advisory; exit 2 (alert) blocks unless
  `ZDOTS_CC_ALLOW_OVERRUN=1` is set and logged. Headless modes (--auto, --sync)
  bypass the gate by design — they should not silently block cron jobs. Wiring `cl`
  (adots) to the same gate is tracked separately.
- **Local lanes** are exempt per constraint 5.
