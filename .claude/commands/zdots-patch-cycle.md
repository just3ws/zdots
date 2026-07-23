---
name: zdots-patch-cycle
description: Work-machine patch export cycle across all three dotfile repos (zdots, adots, vdots) — fetch upstream, rebase local commits, squash to one commit per repo with local delta, export via zdots-patch-export. Use when finishing a work session, preparing changes for the home powerstation, or when asked to "squash and patch", "prepare a patch", or "run the patch cycle". Companion to /zdots-update which covers the home-machine receive side.
---

# /zdots-patch-cycle — Squash and Export (zdots, adots, vdots)

Keeps work-machine commits clean and generates one transferable patch per
repo that actually has local delta. Run at the end of a work session or any
time local commits need to ship home.

**Why squash before patch:** `git format-patch` emits one file per commit.
One squash commit → one `.patch` file, clean `git am` on the other end,
no branch management required.

**Repo invocations** (adots is BARE — never check it like a normal repo):

| Repo | Invocation |
|---|---|
| zdots | `git -C ~/.config/zsh …` |
| vdots | `git -C ~/.config/nvim …` |
| adots | `env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git …` |

A work session can touch any subset of the three (zdots only, or zdots +
adots dotfile tweaks, or a vdots plugin change with no zdots edits at all).
Check all three every time — don't assume zdots-only.

---

## Step 1 — Stay current (all three)

```bash
git -C ~/.config/zsh fetch origin && git -C ~/.config/zsh rebase origin/main
git -C ~/.config/nvim fetch origin && git -C ~/.config/nvim rebase origin/main
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git fetch origin && \
  env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git rebase origin/main
# PASS per repo: "Successfully rebased" or "Current branch main is up to date."
# CONFLICT: resolve in that repo, then git rebase --continue
```

adots routinely carries dirty rc/memory files in the working tree — that's
normal and unrelated to this check (which is commit-based, not dirty-tree
based). Don't sweep them; don't let them block the rebase.

---

## Step 2 — Verify local delta (per repo)

```bash
for pair in "zdots:git -C ~/.config/zsh" "vdots:git -C ~/.config/nvim" \
            "adots:env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git"; do
  label="${pair%%:*}"; cmd="${pair#*:}"
  n=$($cmd log --oneline origin/main..HEAD | wc -l | tr -d ' ')
  echo "$label: $n commit(s) ahead"
done
# A repo with 0 commits ahead needs no patch this cycle — skip it below.
```

For each repo with commits ahead, confirm scope:

```bash
git -C ~/.config/zsh diff --stat origin/main..HEAD      # if zdots ahead
git -C ~/.config/nvim diff --stat origin/main..HEAD      # if vdots ahead
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git diff --stat origin/main..HEAD  # if adots ahead
```

---

## Step 3 — Squash (each repo with delta)

```bash
# zdots
git -C ~/.config/zsh reset --soft origin/main
git -C ~/.config/zsh commit -m "chore(work-session): <summary>

- <bullet per original commit>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

# vdots
git -C ~/.config/nvim reset --soft origin/main
git -C ~/.config/nvim commit -m "chore(work-session): <summary>
..."

# adots (bare — same env prefix for reset/commit as everything else)
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git reset --soft origin/main
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git commit -m "chore(work-session): <summary>
..."
```

Use `chore(work-session):` prefix so the home machine can identify
patch-applied commits in each repo's log. One squash commit per repo with
delta = one logical unit of work per repo.

---

## Step 4 — Export (each repo with delta)

```bash
zdots-patch-export zdots origin/main   # if zdots had delta
zdots-patch-export vdots origin/main   # if vdots had delta
zdots-patch-export adots origin/main   # if adots had delta
# Output: ~/Desktop/outbox/<timestamp>-<label>-origin-main.patch (one per repo)
# Prints: apply with: git am <path>
```

Transfer all generated patch files to the home machine together (AirDrop,
shared folder, etc.) — they're independent and can be applied in any order.

---

## Step 5 — Apply on home machine

```bash
# On home powerstation — if origin already has the changes for a repo:
git -C ~/.config/zsh pull --rebase origin main    # or see /zdots-update
git -C ~/.config/nvim pull --rebase origin main
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git pull --rebase origin main

# If applying a patch file directly (origin not yet updated), use the
# matching invocation for that repo:
git -C ~/.config/zsh am ~/path/to/<timestamp>-zdots-origin-main.patch
git -C ~/.config/nvim am ~/path/to/<timestamp>-vdots-origin-main.patch
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git am ~/path/to/<timestamp>-adots-origin-main.patch
# PASS: "Applied: chore(work-session): ..."
# FAIL: git am --abort (with the matching invocation); inspect conflict; re-export a clean patch
```

---

## Invariants

- Always rebase onto `origin/main` (not `@{u}`) before squashing — explicit ref
  avoids surprises when upstream tracking is misconfigured.
- Never squash across sessions without confirming the working tree is clean.
- Check all three repos every cycle (Step 2) — don't assume zdots-only;
  adots dotfile tweaks or vdots plugin changes can exist with no zdots edits.
- `zdots-patch-export <label> origin/main` is the canonical export command
  for each repo; do not use raw `git format-patch` — the tool handles the
  naming convention and adots' bare-repo invocation.
- One patch per repo-with-delta per session. Old patches in
  `~/Desktop/outbox/` can be removed once the home machine confirms all
  `git am`s succeeded.
