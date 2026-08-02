---
id: doc-003
title: Platform Roadmap 2026-2031 (proposal)
type: other
created_date: '2026-08-02'
---

# Platform Roadmap — 90 days to 5 years (proposal)

Drafted by the maintenance agent from the 2026-08-01/02 maximum-effort audit;
operator edits/blesses. Grounded in measured state, not aspiration.

## Baseline (2026-08-02)

Four repos synced and clean. Standing detectors: doctor daily + suite nightly,
transition-only notify, evidence retained. Hot path: PHI hook 0.08ms, trace
1.5ms (was ~33ms combined). Usage intelligence live (zdots-usage). Knowledge
Layer: 431 Lessons / 113 Methodologies — but the session-side Virtuous Loop is
DORMANT (no `zdots-ctx promote`; capture unscheduled). Work-extension layer
designed (Z-262), tenant extraction incomplete (Z-277/278 pending). Local AI
14B; cloud fan-out constrained by org spend caps.

## 90 days (→ Nov 2026) — close the loop, finish the hygiene

1. **Virtuous Loop session-side** (the single most leveraged gap): `zdots-ctx
   promote` verb, scheduled capture, zdots-usage patterns auto-enqueued as
   Lesson drafts. The platform should learn from usage continuously, not only
   during maximum-effort weekends.
2. Detector maturity: weekly zdots-usage digest through the watch notify
   channel; Z-288 menu-bar pulse (ambient standing state).
3. Debt: Z-282 cwd-dependent PATH root cause; untrack the 18-20MB Go binaries
   (build at install); Z-287 keeps `bin/check` under ~2-3 min.
4. Operator decisions executed: Z-272 deny patch, Z-277/278 untrack, beacon
   cadence decided.

## 6 months (→ Feb 2027) — from detection to safe self-healing

- `zdots doctor --fix=safe` (Z-269) for the verified-inert class only;
  detectors gain propose-fix: auto-filed issue with evidence + suggested
  patch, human applies. Trust is earned per fix-class, never assumed.
- Work-extension proof: zero tenant fragments in platform repos, overlay
  contract audited quarterly.
- Machine parity: `zdots-ctl install` to productive on a fresh Mac < 30 min,
  secrets ritual documented.

## 1 year (→ Aug 2027) — the platform as substrate

- One queryable brain: context-engine + Knowledge Layer unified; semantic
  search across Lessons, Session Residue, and traces.
- Self-describing pipeline (Z-274) done: agents onboard from hydration alone;
  doc drift structurally impossible (contract-tested, as docs-contract already
  proves in miniature).
- Single pulse pane on my.localhost replaces ad-hoc status queries.
- Metrics that matter: median time-to-context for a new agent session < 30s;
  zero silent-red weeks; Lessons cited in hydrated sessions (baseline, then
  grow).

## 2 years (→ Aug 2028) — portable, compounding, semi-autonomous

- Portable personal OS: survives employer changes (work-extension exercised
  for real at least once); any new machine in an afternoon.
- Unattended maintenance windows: nightly upkeep agents within budget
  envelopes, morning digest — the weekend audit becomes a cron.
- Optional: LAN inference node behind the same ZDOTS_AI_ENDPOINT seam —
  contracts already permit it (RFC-1918 locality is enforced, not loopback).

## 5 years (2031) — what should still be true

Specifics at 5 years are fiction; structure is the plan:

- **Contracts outlive implementations.** Seams stay; engines swap (the
  scrubber went bash → Go → resident without callers noticing — that is the
  pattern for everything).
- **The Knowledge Layer is the durable asset.** A decade of curated Lessons
  and Methodologies outvalues any year's tooling. Everything else is
  replaceable; the corpus and the vocabulary are not.
- **Judgment lives in playbooks, not tribal memory.** A 2031 agent (or a
  2031 human) is productive in minutes because the platform describes itself.
- **Anti-goals**: no cloud dependency for core function; no PHI-posture
  erosion for convenience; no second command surface (one vocabulary).

## Cadence

Quarterly maximum-effort audit (this weekend's shape: measure → fix → verify
→ capture Lessons) as the governance ritual; monthly detector review; the
loop does the rest daily.
