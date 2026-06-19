---
name: zdots-patch-cycle
description: Work-machine patch export cycle for zdots: fetch upstream, rebase local commits, squash to one commit, export via zdots-patch-export. Use when finishing a work session, preparing changes for the home powerstation, or when asked to "squash and patch", "prepare a patch", or "run the patch cycle". Companion to /zdots-update which covers the home-machine receive side.
---

# /zdots-patch-cycle — Squash and Export

Keeps work-machine commits clean and generates a single transferable patch.
Run at the end of a work session or any time local commits need to ship home.

**Why squash before patch:** `git format-patch` emits one file per commit.
One squash commit → one `.patch` file, clean `git am` on the other end,
no branch management required.

---

## Step 1 — Stay current

```bash
git fetch origin && git rebase origin/main
# PASS: "Successfully rebased" or "Current branch main is up to date."
# CONFLICT: resolve, then git rebase --continue
```

---

## Step 2 — Verify local delta

```bash
git log --oneline origin/main..HEAD
# Lists commits to be squashed. If empty — nothing to export, stop here.

git diff --stat origin/main..HEAD
# Confirm scope matches what you worked on this session.
```

---

## Step 3 — Squash

```bash
git reset --soft origin/main
git commit -m "chore(work-session): <summary>

- <bullet per original commit>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

Use `chore(work-session):` prefix so the home machine can identify
patch-applied commits in log. One squash commit = one logical unit of work.

---

## Step 4 — Export

```bash
zdots-patch-export zdots origin/main
# Output: ~/Desktop/outbox/<timestamp>-zdots-origin-main.patch
# Prints: apply with: git am <path>
```

Transfer the patch file to the home machine (AirDrop, shared folder, etc.).

---

## Step 5 — Apply on home machine

```bash
# On home powerstation — if origin already has the changes:
git pull --rebase origin main   # standard path; see /zdots-update

# If applying a patch file directly (origin not yet updated):
git am ~/path/to/<timestamp>-zdots-origin-main.patch
# PASS: "Applied: chore(work-session): ..."
# FAIL: git am --abort; inspect conflict; re-export a clean patch
```

---

## Invariants

- Always rebase onto `origin/main` (not `@{u}`) before squashing — explicit ref
  avoids surprises when upstream tracking is misconfigured.
- Never squash across sessions without confirming the working tree is clean.
- `zdots-patch-export zdots origin/main` is the canonical export command;
  do not use raw `git format-patch` — the tool handles naming convention.
- One patch per session. Old patches in `~/Desktop/outbox/` can be removed
  once the home machine confirms `git am` succeeded.
