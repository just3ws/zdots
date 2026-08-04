---
name: platform-sync
description: Review or push the FULL personal-OS platform — all four repos — with the correct git invocations for each. The platform is zdots (kernel) + adots (home-dir config, a BARE repo) + my (private, nested) + vdots (nvim). Use for "review the platform", "is everything pushed/in sync", "prepare the platform for push", or any cross-repo status/sync check.
---

# /platform-sync — the platform is FOUR repos, checked correctly

The personal OS is a **balanced relationship: `zdots` is the kernel, `adots` is
the configuration of the user's home directory.** "The platform" is never one
repo. Any "is it pushed / in sync?" question spans **four** repos, and **adots
is a bare repo** — checking it like a normal repo gives a false "not tracked"
(the documented amnesia failure). This skill encodes the right invocation per repo.

## The four repos (memorize the shape)

| Repo | Role | Where | Git invocation |
|---|---|---|---|
| **zdots** | kernel: services, knowledge, CLI | `~/.config/zsh` | normal `git -C ~/.config/zsh …` |
| **adots** | home-dir config / dotfiles | **bare** `~/.homegit`, work-tree `$HOME` | `GIT_DIR=~/.homegit GIT_WORK_TREE=$HOME git …` (or `homegit` / `adots-git`) |
| **my** | private knowledge vault + context-engine | `~/my` (nested inside adots' work-tree) | normal `git -C ~/my …` |
| **vdots** | nvim config | `~/.config/nvim` | normal `git -C ~/.config/nvim …` |

**adots has NO `.git` inside `~/.config/adots/`** — that directory is just adots'
config files (`capabilities.sh`, `profile`, `wiki`). The repo is the bare
`~/.homegit`. NEVER conclude "adots is untracked" from a missing `.config/adots/.git`.

## Status check (read-only review)

For each repo report: branch · ahead/behind upstream · uncommitted count.

```bash
# zdots / my / vdots — normal repos (fetch already done: skip -q fetch if just fetched)
for r in ~/.config/zsh ~/my ~/.config/nvim; do
  git -C "$r" fetch -q origin 2>/dev/null
  echo "$r: branch=$(git -C "$r" branch --show-current 2>/dev/null) ahead=$(git -C "$r" rev-list --count origin/main..HEAD 2>/dev/null) behind=$(git -C "$r" rev-list --count HEAD..origin/main 2>/dev/null) dirty=$(git -C "$r" status --short 2>/dev/null | wc -l | tr -d ' ')"
done

# adots — bare repo; @{u} fails (no upstream tracking config), use origin/main explicitly
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git fetch -q origin 2>/dev/null
echo "adots: branch=$(env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git branch --show-current 2>/dev/null) ahead=$(env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git rev-list --count origin/main..HEAD 2>/dev/null) behind=$(env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git rev-list --count HEAD..origin/main 2>/dev/null) dirty=$(env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git status --short --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')"
# Detail on adots dirty files (tracked only):
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git status --short --untracked-files=no 2>/dev/null | head -10
```

**Report format** — 4-row table: repo · sync (ahead/behind) · dirty count · what's dirty.

## CI health (don't stop at "the runs exist")

`ahead=0 behind=0` only proves the repo is pushed — it says nothing about whether
main is green. Check the actual `conclusion` of the latest run on each repo's
real test/lint/build workflow, not just that runs exist:

```bash
gh -R <owner>/<repo> run list --branch main --limit 5
```

A feed of `Dependabot Updates` / scheduled-bot runs is not evidence of green —
those workflows don't exercise the repo's own tests. Find the workflow that
actually lints/builds/tests (check `.github/workflows/`) and read *its*
conclusion. adots typically has no CI configured — that's expected, not a gap.

## Fixing a CI failure found during this check

adots/my/vdots are not covered by the zdots-specific "not yours to fix" carve-out
(AGENTS.md §5 — that rule is about zdots' shared infrastructure and its unknown
callers, not the whole platform). A quick, well-understood, verified fix to one
of the other three repos' own config is in scope to make directly, same as any
other repo you maintain — no `zdots-issue` needed.

**But CI fixes cascade — don't declare green after one commit.** A dependency
install bug can mask a formatting bug can mask a missing plugin-install step.
After every push, re-poll `gh run view <id> --json status,conclusion` until
`status=completed`, and only report "fixed" when `conclusion=success`. If a new
failure surfaces after a fix that's a *different class* of problem (not more
CI plumbing but a real environment/architecture gap), stop and flag it instead
of continuing to patch — that's a scope call for the operator, not a quick fix.

## Post-pull checklist (after pulling zdots)

After a `git pull --ff-only origin main` on zdots, check for pending work:

```bash
# Migration gate — run if db/migrations/ changed
git -C ~/.config/zsh diff ORIG_HEAD..HEAD --name-only | grep -q 'db/migrations/' && \
  echo "MIGRATION NEEDED: zdots-ctx migrate" || echo "no migration"

# PHI patterns changed — shell restart recommended
git -C ~/.config/zsh diff ORIG_HEAD..HEAD --name-only | grep -q 'phi-patterns.yaml' && \
  echo "PHI PATTERNS UPDATED: restart shell" || true

# Service registry changed — restart all services
git -C ~/.config/zsh diff ORIG_HEAD..HEAD --name-only | grep -q 'svc-registry.bash' && \
  echo "SVC REGISTRY CHANGED: zdots-ctl reset" || true
```

Full post-pull reconciliation: `/zdots-update`.

---

## Push

Push only repos with `ahead>0`. adots pushes through the bare invocation:
`env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git push origin main`.

## Beacon (Astronomicon)

The public trio (zdots/adots/vdots) shares ONE imperial-CalVer stamp per release;
`my` conforms by contract. Re-stamp at release: `imperial-date > VERSION`, commit,
`make changelog` (decision-007 §5). `zdots-doctor` reports beacon drift across
peers; vdots having no VERSION = "rollout pending" (forward-compat, not an error).

## Rules — separate repos, separate operators

- **Never sweep.** Each repo can carry large unrelated uncommitted work (e.g. `~/my`
  mid-restructure with 100+ changed files). When committing one thing, `git add`
  the exact path(s) only — never `git add -A` across a repo you don't own the diff of.
- **Don't reach across boundaries.** A change one repo needs from another is an
  issue to file, not a cross-repo edit (peer architecture; AGENTS.md §5).
- `bin/secret-scan` before any commit (these repos touch `$HOME` — the PHI/secret surface).
- Report a 4-row table: repo · sync · dirty · CI. Anything dirty gets a
  one-line "whose / what", not silence; CI gets success/failure, not just "ran".
