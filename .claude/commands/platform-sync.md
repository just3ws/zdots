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
# zdots / my / vdots — normal repos
for r in ~/.config/zsh ~/my ~/.config/nvim; do
  git -C "$r" fetch -q origin 2>/dev/null
  echo "$r: ahead=$(git -C "$r" rev-list --count @{u}..HEAD 2>/dev/null) behind=$(git -C "$r" rev-list --count HEAD..@{u} 2>/dev/null) dirty=$(git -C "$r" status --short | wc -l)"
done
# adots — bare repo, work-tree $HOME
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git fetch -q origin 2>/dev/null
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git -C $HOME status --short --untracked-files=no | head
```

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
- Report a 4-row table: repo · sync · pushed · dirty. Anything dirty gets a
  one-line "whose / what", not silence.
