---
name: zdots-update
description: Guide for safely pulling and applying zdots repo updates. Verifies system readiness, runs zdots-update-local, and validates the result. Haiku-friendly — every step is a concrete runnable command.
---

# /zdots-update — Pull and Apply zdots Updates

Run this skill when pulling changes from the zdots repo. It verifies the
system is ready, applies the update, and confirms everything still works.

---

## Phase 0 — Pre-flight (run before git pull)

```bash
# P0-A: confirm working tree is clean (no uncommitted work to lose)
git -C "$ZDOTDIR" status --short
# PASS: no output
# FAIL: stash or commit first — git -C "$ZDOTDIR" stash

# P0-B: services are healthy (don't update a broken machine)
zdots-ctl status --json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
failed = [k for k,v in d.items() if v is False and k not in ('intelligence_suite',)]
print('PASS' if not failed else 'FAIL: ' + str(failed))
"
# PASS: "PASS"
# FAIL: fix services with zsvc start <svc> before proceeding

# P0-C: note current HEAD for diff after pull
git -C "$ZDOTDIR" rev-parse HEAD
# Save this value — you'll use it in Phase 2
```

---

## Phase 1 — Pull

```bash
git -C "$ZDOTDIR" pull --ff-only origin main
# PASS: "Fast-forward" or "Already up to date."
# FAIL: non-fast-forward → investigate; do NOT force-merge without operator approval
```

```bash
# What changed?
git -C "$ZDOTDIR" log --oneline ORIG_HEAD..HEAD
# Read the commit list. If you see changes to:
#   lib/svc-registry.bash  → service catalog changed; services may need restart
#   db/migrations/         → migration required (see Phase 2-B)
#   etc/phi-patterns.yaml  → PHI patterns updated; shell restart recommended
#   bin/zdots-doctor       → doctor behavior changed; re-read --help
#   Brewfile.*             → packages changed (brew bundle will handle in Phase 2)
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
Pull:     <old-HEAD>..<new-HEAD>
Commits:  <N> commits
Phases:   <N>/14 completed  (list any skipped)

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
