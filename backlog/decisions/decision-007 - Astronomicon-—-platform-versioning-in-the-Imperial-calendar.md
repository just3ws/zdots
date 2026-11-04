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

Initial release: **`0452026.M3`** (2026-06-14). `bin/imperial-date` computes the stamp
(and decodes one, ±1 day — the fraction granularity is ~8.76h). It is plain CalVer
underneath; the Imperial form is the character, not a different scheme.

**2. Six deployed surfaces share ONE epoch per release.** zdots, adots, `my`,
vdots, media-pipeline, and the just3ws.github.io site each carry a root `VERSION`
file with the *same* stamp. The just3ws.com and localhost/LAN host aliases resolve
to the same site repo. Equal stamps mean in sync; differing stamps are **deploy
drift** (the miasma), surfaced rather than silently tolerated.

**3. `my` carries both the epoch and its independent structure contract.** `my`
declares `my.structure.v1` (governed by `adots-my`) and carries the same
Astronomicon `VERSION` as the other deployed surfaces. Both `just3ws/my` and
`myworkname/my` conform to the same contract and epoch while holding different
content. The shared epoch is release metadata only; it never carries content
across the home/work boundary.

**4. The beacon is reported as ground truth.** `capabilities` and `agent-guide`
emit `platform.version` (text + JSON), the `my` epoch, and the structure
contract. `zdots-doctor` compares all six `VERSION` markers (absence = "rollout
pending", forward-compatible) and reports drift. SwiftBar displays the zdots
epoch and links to the drift check.

**5. Stamping a release.** Calculate the Imperial date once with `imperial-date`,
write that exact value to each of the six root `VERSION` files, commit each
repository's scoped change, and push. Use `adots-git` for the home-directory repo.
Update `CHANGELOG.md` where maintained and run `make changelog` in zdots. Tags
may mirror the stamp.

## Consequences

Positive: a deploy onto the work machine has a single verifiable reference point —
`zdots-doctor` answers "are the system surfaces aligned?" before work begins; the
home/work `my` separation remains encoded as policy, not memory; `capabilities`,
`agent-guide`, and SwiftBar make the platform version legible in normal workflows.

Negative: stamping is a manual release ritual across six repos (mitigated by
`imperial-date` + the doctor sync check catching drift); the Imperial form is
opaque without the key (mitigated by the decode mode and the Gregorian annotation
in `capabilities`/`doctor`); the year-fraction is ~8.76h-granular, so same-day
re-cuts share a stamp (acceptable for an epoch).

Current beacon update (2026-11-04): **`0843026.M3`** is aligned across zdots,
adots, my, vdots, media-pipeline, and just3ws.github.io. The my structure
contract remains `my.structure.v1`. SwiftBar displays the zdots beacon. Earlier
rollout history remains in Git.

Related: project_my_system (home/work split), project_work_machine_deploy,
the capabilities/agent contract. "The Emperor Protects."
