---
id: decision-007
title: Astronomicon — platform versioning in the Imperial calendar
date: '2026-06-15 00:49'
status: accepted
---
## Context

The personal-OS platform is four systems deployed across two machines (home
powerstation, work). Three are **public, shared wisdom carried forward** to both:
**zdots** (shell control plane), **adots** (home/agent dotfiles), **vdots**
(Neovim). The fourth, **`my`** (Cerebral Control Plane), is **private and
per-environment**: `just3ws/my` at home, a separate `myworkname/my` at work — same
structure, different content, deliberately kept apart so personal and work
(PHI-adjacent) material never mix.

Before this decision there was no version reference point: no `VERSION` files, one
ad-hoc tag (`v2026.03-shell-baseline`), and `capabilities` reported no version. On
a deploy (a `git pull` onto the work machine) there was no way to assert the
systems were mutually consistent — drift was invisible until something broke.

The system needs a single guiding reference — an **Astronomicon**: a beacon every
deploy navigates by to stay aligned through the chaos.

## Decision

**1. One beacon, the Imperial-CalVer epoch.** The platform version is a calendar
version expressed in the **Imperial Dating System** of the Imperium of Mankind, in
keeping with the Astronomicon. Format `CFFFYYY.M#`:

| Field | Meaning |
|---|---|
| `C` | Check Number (0 = verified at the source / most accurate class) |
| `FFF` | Year Fraction 000–999 (elapsed fraction of the Gregorian year) |
| `YYY` | Year within the millennium |
| `M#` | Millennium (M3 = 2001–3000) |

This release: **`0452026.M3`** (2026-06-14). `bin/imperial-date` computes the stamp
(and decodes one, ±1 day — the fraction granularity is ~8.76h). It is plain CalVer
underneath; the Imperial form is the character, not a different scheme.

**2. The public trio shares ONE epoch per deploy.** zdots, adots, and vdots each
carry a `VERSION` file holding the *same* stamp for a given release. Equal stamps =
in sync; differing stamps = **deploy drift** (the miasma), surfaced — not silently
tolerated.

**3. `my` attests to a contract, not the epoch.** `my` declares
`my.structure.v1` (governed by `adots-my`). Both `just3ws/my` and `myworkname/my`
conform to the *same contract version* while holding *different content*. `my` is
never stamped with the public epoch and never carries content across the home/work
boundary.

**4. The beacon is reported as ground truth.** `capabilities` emits
`platform.version` (text + JSON). `zdots-doctor` has a *Platform version
(Astronomicon)* section that reads zdots's beacon and compares the public peers'
`VERSION` when present (absence = "rollout pending", forward-compatible), and
reports the `my` contract. Reading the Astronomicon is one command.

**5. Stamping a release.** Cut a release by writing the current Imperial date into
each public repo's `VERSION` (`imperial-date > VERSION`), committing, and updating
`CHANGELOG.md`. Tags may mirror the stamp.

## Consequences

Positive: a deploy onto the work machine has a single verifiable reference point —
`zdots-doctor` answers "are the public systems aligned?" before work begins; the
home/work `my` separation is encoded as policy, not memory; `capabilities` makes
the platform version legible to humans and agents in one turn.

Negative: stamping is a manual release ritual across three repos (mitigated by
`imperial-date` + the doctor sync check catching drift); the Imperial form is
opaque without the key (mitigated by the decode mode and the Gregorian annotation
in `capabilities`/`doctor`); the year-fraction is ~8.76h-granular, so same-day
re-cuts share a stamp (acceptable for an epoch).

Rollout: **zdots core landed this session** (VERSION beacon, `bin/imperial-date`,
`capabilities`, `zdots-doctor` sync check, this record, CHANGELOG). adots/vdots
`VERSION` files and the `my.structure` contract version are the coordinated next
step, run when deploying.

Related: project_my_system (home/work split), project_work_machine_deploy,
the capabilities/agent contract. "The Emperor Protects."
