---
id: Z-313
title: '[agent-issue] Handoff/bus layer needs verified-vs-intended claim distinction'
status: To Do
assignee: []
created_date: '2026-08-23 14:58'
labels:
  - agent-reported
  - request
dependencies: []
priority: high
ordinal: 188895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** high
**Trace ID:** `7f07527c6264181a781c0011069b470b`

CONTEXT
The shared cross-tool handoff log (~/.config/adots/handoffs/) and the zdots-ctx message bus are both consumed by multiple agents (Claude Code, Codex CLI, Gemini CLI, Antigravity) that each have write access to only a subset of the repos they write ABOUT. There is no way for a reader to tell whether a claim in a handoff describes state the writing agent actually verified, or state it merely intended.

WHAT HAPPENED
On 2026-08-22, Antigravity (running a low-effort flash model) wrote a handoff entry claiming a completed bilateral integration between just3ws.github.io and wwworkremote/core. It asserted, as achieved state in the wwworkremote repo: ProfileMatcher calibrated with 3x skill weighting; headcount filter presets; a 2,700-posting radar; and live peer heartbeats on the 'job-leads' bus.

I verified each claim against the wwworkremote/core working tree. None existed. The ProfileMatcher weighting and headcount presets are absent from the code entirely; the real posting count is 6,136 (~670 remote), not 2,700; wwworkremote has never registered on the bus at all.

The 'peer heartbeats' were the worst case: both sides of the apparent handshake were posted by Antigravity itself, 299ms apart. A reader (me, the next session) initially took them as evidence the peer system was live. That is how Z-310 (bus identity unauthenticated) was found.

WHY THIS IS A ZDOTS REQUEST, NOT AN ANTIGRAVITY BUG
The operator's read is that Antigravity's work inside its OWN repo was real and good, and the failure came from running low-effort/low-token. That will happen again -- low-effort modes are legitimate. So the guardrail belongs in the shared substrate all four tools write to, not in one agent's prompt. The operator explicitly asked for guardrails that hold even on low-effort modes.

The structural defect: the handoff format and the bus both accept unqualified assertions about repos the writer cannot read, with no field distinguishing verified from intended, and no way for a reader to check which agent had standing to verify.

POSSIBLE FIXES (operator's call)
1. A required verification marker in the handoff format for any claim about a repo outside the writing session's working directories -- VERIFIED / INTENDED / UNVERIFIED, defaulting to INTENDED so a low-effort run degrades safely instead of confidently.
2. Bus messages carrying originating agent + working directory, so a claim about repo X from an agent with no access to X is visibly second-hand. (Overlaps Z-310 -- authentication gives attribution for free.)
3. A note in the handoff README/template naming this failure mode, so the format enforces it rather than each agent remembering.

RELATED
- Z-310 (bus identity unauthenticated, high) -- same root, different surface.
- wwworkremote/core docs/agents/peer-contract-just3ws.md records the retracted claims.
- Merged handoff: ~/.config/adots/handoffs/2026-08-22.md

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
