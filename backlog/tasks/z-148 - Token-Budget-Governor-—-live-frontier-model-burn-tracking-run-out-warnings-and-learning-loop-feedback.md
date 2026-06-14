---
id: Z-148
title: >-
  Token-Budget Governor — live frontier-model burn tracking, run-out warnings,
  and learning-loop feedback
status: To Do
assignee: []
created_date: '2026-06-14 18:25'
labels:
  - feature
  - ai-cost
  - observability
  - knowledge-layer
dependencies: []
references:
  - >-
    backlog/decisions/decision-006 -
    Frontier-Model-Token-Budget-Safety-constraint.md
priority: medium
ordinal: 39890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Capability request (for consideration). Satisfies the Frontier-Model Token-Budget Safety constraint (decision-006) for Claude Code first, then the opt-in cloud lanes (project_frontier_lanes).

PROBLEM
Frontier sessions (Claude Code, and zaider --hf / zpi --or / zopencode --gh) meter real money under hard session and rate limits, with no live signal for remaining headroom or burn rate. Symptoms: sessions run out mid-task and leave work in an incomplete, unrecoverable state; no warning before getting 'hot'; no recommendation of where to stop, compact, or optimize; no defense against spending past the operator's intended account level. Mike needs to PLAN around these constraints safely.

SCOPE (a Token-Budget Governor capability)
1. Live headroom signal. Surface remaining session/rate budget + burn rate in the cc-statusline (and an on-demand query). Escalating states: nominal -> warm -> hot -> critical. Label any estimated figure as an estimate (harness may not expose exact remaining tokens).
2. Stop/compact recommendations. At 'hot'/'critical', recommend a safe action — compact now, checkpoint, or stop at a recoverable point — BEFORE a hard failure. Identify concrete optimization points (e.g. high-output commands not proxied through rtk, oversized context loads, repomix when narrower would do).
3. Spend ceiling (fail-closed). Warn as projected spend approaches the operator's configured account level; crossing it requires an explicit, logged opt-in (parallel to --allow-private / cloud-lane opt-in). Default: stop, do not spend.
4. Metering -> Knowledge Layer. Capture token/cost/latency per frontier call as OpenObserve runtime telemetry (llm_call spans already exist) and fold session efficiency into the Virtuous Loop so highly-successful sessions can be distinguished from wasteful ones over time — not just live insight, but trend analysis (cost-per-completed-task, burn-rate-vs-outcome).
5. Capacity model. Give Mike a planning answer to 'how much can I safely attempt this session?' from his actual account levels and recent burn history.

CANDIDATE INTEGRATION POINTS (verify before building — do not assume these exist as described)
- cc-statusline (live gauge), cc-doctor (config/limit audit surface).
- OpenObserve llm_call spans (already emitting; extend with token/cost dims).
- Session Residue + session-debrief write-back (the Infer step; project_intelligence_layer) for per-session efficiency capture.
- bin/history-intelligence for cross-session trend analysis.
- lib/ai_cloud_lane.bash as the hook point for cloud-lane metering.

NON-GOALS
- Local lanes (ai-query, llama.cpp) — exempt per decision-006 (no spend/hard limit).
- Re-architecting the AI invocation interface (tracked separately, Z-130).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Live frontier-session headroom + burn rate is visible (statusline + on-demand query), with estimated values labeled as estimates
- [ ] #2 At 'hot'/'critical' the system recommends a safe action (compact/checkpoint/stop) before any hard limit failure, and names at least one concrete usage-optimization
- [ ] #3 Projected spend approaching the configured account level warns; crossing it fails closed and requires an explicit logged opt-in
- [ ] #4 Per-call token/cost/latency is captured as runtime telemetry and a per-session efficiency record reaches the Knowledge Layer for trend analysis
- [ ] #5 decision-006 constraint is documented and the governor is registered against it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Design-first; deliver incrementally. Phase 0: confirm which budget/limit signals the Claude Code harness actually exposes (exact vs estimated) — this bounds everything downstream. Phase 1: passive metering — emit token/cost/latency spans + a per-session efficiency record (no enforcement). Phase 2: live headroom gauge in cc-statusline + on-demand query with nominal/warm/hot/critical thresholds. Phase 3: stop/compact recommendations + named optimization hints at the boundary. Phase 4: fail-closed spend ceiling with logged opt-in. Phase 5: capacity model + successful-vs-wasteful session analysis fed back via history-intelligence / session-debrief.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Consideration item raised 2026-06-14. The cost-side analogue of PHI Operating Mode: a fail-closed guardrail, but for spend/exhaustion instead of leakage. Constraint codified in decision-006 (proposed). Verify all candidate integration points against the tree before implementing — file a zdots-issue if a named seam is missing rather than inventing one.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
