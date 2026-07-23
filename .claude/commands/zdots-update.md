---
name: zdots-update
description: Guide for safely pulling and applying zdots, adots, and vdots repo updates. Verifies system readiness, applies zdots/adots/vdots patches or pulls, runs zdots-update-local, and validates the result across all three. Haiku-friendly — every step is a concrete runnable command.
---

# /zdots-update — Pull and Apply zdots + adots + vdots Updates

Run this skill when pulling changes into zdots, adots, and/or vdots — whether
via direct pull or a patch file from `/zdots-patch-cycle` on the work machine.
Companion of that skill: it exports per-repo patches, this applies them.
Not every session touches all three — check each independently.

**Repo invocations** (adots is BARE — never check it like a normal repo):

| Repo | Invocation |
|---|---|
| zdots | `git -C "$ZDOTDIR" …` |
| vdots | `git -C ~/.config/nvim …` |
| adots | `env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git …` |

---

## Phase 0 — Pre-flight (run before any pull/am)

```bash
# P0-A: confirm all three working trees are clean (no uncommitted work to lose)
git -C "$ZDOTDIR" status --short
git -C ~/.config/nvim status --short
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git status --short
# PASS: no output (adots may show dirty rc/memory files — normal, not blocking)
# FAIL (zdots/vdots dirty): stash or commit first — git -C <repo> stash

# P0-B: services are healthy (don't update a broken machine)
zdots-ctl status --json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
failed = [k for k,v in d.items() if v is False and k not in ('intelligence_suite',)]
print('PASS' if not failed else 'FAIL: ' + str(failed))
"
# PASS: "PASS"
# FAIL: fix services with zsvc start <svc> before proceeding

# P0-C: note current HEAD for diff after pull, for each repo you'll update
git -C "$ZDOTDIR" rev-parse HEAD
git -C ~/.config/nvim rev-parse HEAD
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git rev-parse HEAD
# Save these — you'll use them in later phases
```

---

## Phase 1 — Pull (per repo — do the ones that actually have incoming changes)

Two paths per repo — use whichever applies. Only run the block for a repo
that changed; not every session touches all three.

**A. Direct pull (origin has the changes):**
```bash
git -C "$ZDOTDIR" pull --ff-only origin main
git -C ~/.config/nvim pull --ff-only origin main
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git pull --ff-only origin main
# PASS: "Fast-forward" or "Already up to date."
# FAIL: non-fast-forward → investigate; do NOT force-merge without operator approval
```

**B. Patch file (from work machine via /zdots-patch-cycle):**
```bash
git -C "$ZDOTDIR" am ~/path/to/<timestamp>-zdots-origin-main.patch
git -C ~/.config/nvim am ~/path/to/<timestamp>-vdots-origin-main.patch
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git am ~/path/to/<timestamp>-adots-origin-main.patch
# PASS: "Applied: chore(work-session): ..."
# FAIL: git am --abort (same invocation as the failing repo); ask operator to re-export a clean patch
```

```bash
# What changed? (run for each repo you updated)
git -C "$ZDOTDIR" log --oneline ORIG_HEAD..HEAD
git -C ~/.config/nvim log --oneline ORIG_HEAD..HEAD
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git log --oneline ORIG_HEAD..HEAD
# Read the commit list. If you see changes to:
#   lib/svc-registry.bash  → service catalog changed; services may need restart
#   db/migrations/         → migration required (see Phase 2-B)
#   etc/phi-patterns.yaml  → PHI patterns updated; shell restart recommended
#   bin/zdots-doctor       → doctor behavior changed; re-read --help
#   Brewfile.*             → packages changed (brew bundle will handle in Phase 2)
#   nvim-pack-lock.json    → vdots plugin set changed (see Phase 2-E)
#   .bash_profile/.bashrc/.zshenv, .config/git/config → adots entrypoint/git
#     config changed; re-run adots-doctor after (Phase 4)
```

---

## Phase 2 — Reconcile (zdots-update-local)

```bash
# P2-A: dry run first — see what will happen
zdots-update-local --dry-run 2>&1 | head -60
# Read the phase list. Verify it matches expectations from the commit log.
```

```bash
# P2-B: if db/migrations/ changed, migrate first
git -C "$ZDOTDIR" diff ORIG_HEAD..HEAD --name-only | grep -q 'db/migrations/' && \
  echo "MIGRATION NEEDED" || echo "no migration"
# If MIGRATION NEEDED: zdots-ctx migrate
```

```bash
# P2-C: run the update
zdots-update-local 2>&1 | tee /tmp/zdots-update-run.log
# PASS: exits 0, summary shows no [FAIL] lines
# FAIL: see Phase 3 (diagnosis)
```

```bash
# P2-D: check the summary for failures
grep -E '\[FAIL\]|ERROR' /tmp/zdots-update-run.log
# PASS: no output
# FAIL: read the failing phase name; skip flags available per phase:
#   --skip-brew  --skip-mise  --skip-gems  --skip-llama  --skip-fabric
#   --skip-aider  --skip-gemini  --skip-python  --skip-index-tools
#   --skip-otel  --skip-check
```

```bash
# P2-E: vdots only — if nvim-pack-lock.json changed, sync plugins + verify
git -C ~/.config/nvim diff ORIG_HEAD..HEAD --name-only | grep -q 'nvim-pack-lock.json' && {
  cd ~/.config/nvim
  nvim --headless -u init.lua +"lua vim.pack.update()" +qa
  nvim --headless -u init.lua -c "luafile test/regression.lua" +qa 2>&1 | tail -6
} || echo "no vdots plugin changes"
# PASS: regression suite prints "All tests passed!"
# FAIL: read which test failed; the diff that broke it is in ORIG_HEAD..HEAD above
```

```bash
# P2-F: adots only — entrypoint symlinks and git config are the only
# "generated" state; there's no reconcile-local equivalent, adots-doctor
# in Phase 4 covers verification. Nothing to run here.
```

---

## Phase 3 — Diagnosis (if Phase 2 failed)

```bash
# P3-A: structured log analysis
zdots-log-analyze update 2>/dev/null | head -40
# Shows: which phase failed, timing, error message
```

```bash
# P3-B: tail the most recent update log
ls -t ~/.local/state/zsh/zdots-update-local-*.log 2>/dev/null | head -1 | \
  xargs tail -50
```

**Common failures and fixes:**

| Phase fails | Symptom | Fix |
|-------------|---------|-----|
| brew bundle | package conflict | `brew doctor` then re-run |
| mise install | version missing | `mise install` manually then re-run `--skip-brew` |
| llama plist | port conflict | `zsvc stop llama && zdots-update-local --skip-brew --skip-mise --skip-gems` |
| otel validate | config syntax | check `etc/otel-collector.yaml` against docs/otel-collector-guide.md |
| make check-fast | test failure | run `bats tests/` to identify; file `zdots-issue` if pre-existing |

If a phase fails and no fix is obvious: `zdots-issue --high "zdots-update-local: phase <name> failed after pull <commit>"` then stop.

---

## Phase 4 — Validate

```bash
# P4-A: platform health
zdots-ctl check 2>&1 | grep -E 'FAIL|ERROR' | grep -v '^#'
# PASS: no output

# P4-B: doctor (fast mode)
zdots-doctor --no-runtime --quiet 2>&1 | grep -E '\[FAIL\]'
# PASS: no output

# P4-C: services still running
zsvc list 2>/dev/null | awk 'NR>1 && $2 != "running" {print "DOWN:", $1}'
# PASS: no output
# FAIL: zsvc start <svc>

# P4-D: log sizes didn't spike
zdots-logs check 2>&1 | grep -E 'CRIT|FAIL'
# PASS: no output (or only pre-existing CRITs from before the update)

# P4-E: knowledge base reachable and catalog fresh
zdots-ctx status --json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('connected', 'PASS' if d.get('connected') or d.get('db_connected') else 'FAIL')
"
zdots-ctx query tooling:catalog 2>/dev/null | grep -c 'tooling:' | \
  awk '{print ($1 > 0) ? "PASS (catalog present)" : "FAIL"}'

# P4-F: adots health (only meaningful if you applied an adots update)
adots-doctor 2>&1 | tail -5
# PASS: "adots=healthy zdots=healthy" / "ok with 0 warning(s)"
# FAIL: read the failing check; do not run --fix blind — read what it would
#   change first (it backs up before overwriting, but confirm scope)
```

---

## Phase 5 — Services that need restart after updates

```bash
# If svc-registry.bash changed: restart all managed services
git -C "$ZDOTDIR" diff ORIG_HEAD..HEAD --name-only | grep -q 'svc-registry.bash' && \
  echo "RESTART ALL" || echo "no restart needed"
# If RESTART ALL: zdots-ctl reset
```

```bash
# If llama plists changed: restart llama
git -C "$ZDOTDIR" diff ORIG_HEAD..HEAD --name-only | grep -q 'llama' && \
  { zsvc restart llama; zsvc restart embed; } || true

# If otel-collector.yaml changed: restart otel
git -C "$ZDOTDIR" diff ORIG_HEAD..HEAD --name-only | grep -q 'otel-collector.yaml' && \
  zsvc restart otel || true
```

---

## Reporting Format

```
=== zdots-update report — <timestamp> ===
zdots:  <old-HEAD>..<new-HEAD> (<N> commits, or "unchanged")
vdots:  <old-HEAD>..<new-HEAD> (<N> commits, or "unchanged")
adots:  <old-HEAD>..<new-HEAD> (<N> commits, or "unchanged")
Phases: <N>/14 completed (list any skipped)

PASS | FAIL per phase

── FIXED ─────────────────────────────────
- <what was done automatically>

── OPERATOR NEEDED ───────────────────────
- <what needs attention + zdots-issue ID>
```

---

## Hard Limits

- Never `git pull --force` or `git reset --hard` without operator approval.
- Never apply migrations in reverse.
- Never restart services more than once per update run.
- If any `[FAIL]` in zdots-update-local output is not in the table above:
  `zdots-issue --high "zdots-update-local: unknown failure in phase <name>"` then STOP.
