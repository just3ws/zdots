---
id: doc-004
title: North Star and Measurement Framework
type: other
created_date: '2026-08-02'
---

# North Star & Measurement Framework

Companion to doc-003 (roadmap/vision). doc-003 says where; this says how we
know we are on course. Every metric here is queryable with tooling that
exists today (`zdots-usage`, `zdots-ctx status`, `zdots-watch status`,
`bench startup`, `rtk gain`) or is explicitly flagged as an instrumentation
gap owned by a task.

## North Star

**The platform learns faster than it decays.**

North Star Metric (NSM): **Loop velocity** — curated knowledge units produced
AND consumed per week (Session Residues promoted to Lessons; Lessons cited in
hydrated sessions). Today it is **zero** (loop dormant, Z-289–291). The NSM is
deliberately not a performance or uptime number: speed and health are
*conditions* for learning, not the goal.

## The alignment test

Every task, before it is taken, names which lever it pulls — one line in the
task body. Work that pulls none gets questioned, not silently done:

| Lever | Question it serves | Example from the record |
|---|---|---|
| **DETECT** | Does the system notice decay sooner? | zdots-watch (Z-268/281), evidence retention (Z-284) |
| **LEARN**  | Does it feed or speed the loop? | zdots-usage (Z-286), promote verb (Z-289) |
| **COMPOUND** | Does it strengthen a contract/Seam? | resident scrubber (Z-283), trace convergence |
| **OPERATE** | Does it cut the human-mechanic tax? | --fix=safe (Z-269), pulse widget (Z-288) |

## KPIs and baseline (measured 2026-08-02)

| KPI | Baseline | Direction | Source |
|---|---|---|---|
| Loop: residues captured /wk | ~0 (23 total, manual) | up | `zdots-ctx status` |
| Loop: promotions to Lessons /wk | 0 (verb missing) | up | promote verb (Z-289) |
| Knowledge: Lessons / Methodologies | 432 / 114 | up, curated | `zdots-ctx status` |
| Loop: % sessions hydrated citing a Lesson | unmeasured | instrument | gap → Z-291 scope |
| Health: silent-red days /mo | was weeks (13 rotted tests); detectors live 08-01 | 0 | zdots-watch state + evidence |
| Health: regressions caught by detector vs human | new metric | detector-first | watch log worsened lines |
| Perf: per-command tax (hook+trace) | 1.6 ms (was ~33) | hold < 3ms | bench in phi/trace commits |
| Perf: warm shell startup | 333 ms | < 300 | `bench startup` |
| Perf: bin/check wall time | 4:47 two-lane (was ~7:00) | < 3:00 | timed runs |
| Quality: bats suite green rate | 782+ tests, green | 100% nightly | run-check state |
| Quality: docs-contract known-gaps count | ledger length | down | docs/generated ledger |
| Security: secret-scan findings /commit | 0 | 0 always | pre-commit ritual |
| Security: known allowlist holes | 1 (Z-272 patch pending) | 0 | audit notes |
| Autonomy: operator interventions needed /wk | unmeasured | down over years | quarterly audit review |

## OKRs — Q through Nov 2026 (matches doc-003 90-day)

**O1 — Close the learning loop** (NSM goes nonzero)
- KR1: `zdots-ctx promote` ships; ≥1 residue→Lesson end-to-end (Z-289)
- KR2: capture runs unattended; ≥5 residues/wk, zero manual steps (Z-290)
- KR3: Monday usage digest live; ≥3 Lesson drafts born from usage patterns (Z-291)

**O2 — Nothing regresses silently**
- KR1: 0 silent-red weeks from 08-02 onward (nightly check + daily doctor, evidence retained)
- KR2: bin/check ≤ 3:00 (Z-287 landed at 4:47; serial-lane tuning remains)
- KR3: ambient pulse visible (Z-288) — standing state without asking

**O3 — Pay the structural debt**
- KR1: Z-282 cwd-PATH root cause fixed with a regression test
- KR2: Go binaries untracked, build-at-install on both machines (Z-292)
- KR3: operator decision queue emptied (Z-272 deny patch, Z-277/278, beacon cadence)

## Milestones & checkpoints

- **M1 — Sep 1:** promote verb live. Checkpoint: one real Lesson born from
  this machine's residue, curated by the operator.
- **M2 — Oct 1:** loop unattended. Checkpoint: one full hands-off week —
  capture, digest, ≥1 draft Lesson, no manual steps.
- **M3 — Nov 1:** quarterly audit #2. Checkpoint: this KPI table re-measured
  against baseline; OKRs graded; next quarter's OKRs cut from the deltas.

## Cadence (who checks what, when)

- **Daily** — detectors (doctor, nightly suite): machine's job.
- **Weekly** — usage digest (Z-291): machine drafts, operator skims.
- **Monthly** — KPI snapshot into the handoff (5 minutes: ctx status,
  watch status, bench, check timing); detector review.
- **Quarterly** — maximum-effort audit (the 2026-08 weekend is the
  template): re-measure everything, grade OKRs, capture Lessons, set next
  OKRs. The roadmap doc gets a dated addendum, never a rewrite.

## Anti-metrics (things we refuse to optimize)

- Lines of code, number of tools, commit counts — machinery is a cost.
- Cloud-token savings at the expense of local-first posture.
- Autonomy percentage at the expense of the PHI perimeter: some prompts are
  the product working, not friction to remove.
