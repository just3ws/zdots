---
name: platform-integrate
description: Integrate upstream main into the local work branch across all four platform repos (zdots, adots, my, vdots) — lineage-continuity gate, history-rewrite protocol, machine-specific conflict policy, backlog ID collision scan, post-merge reconciliation and validation.
---

# /platform-integrate — pull upstream main into work, safely, all four repos

The loop on this machine (see memory / charter): local commits live on `work`;
upstream `main` is merged INTO `work` here; `work`→`main` integration happens
home-side. The operator pushes (cc-hook-guard blocks CC push). This skill
encodes the protocol learned 2026-07-20/21, including the `my` history-rewrite
incident and two backlog ID collisions.

**Repo invocations** (adots is BARE — never check it like a normal repo):

| Repo | Invocation |
|---|---|
| zdots | `git -C ~/.config/zsh …` |
| my | `git -C ~/my …` |
| vdots | `git -C ~/.config/nvim …` |
| adots | `env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git …` |

---

## Phase 0 — Record pre-fetch tips, then fetch

```bash
# Record each repo's current origin/main BEFORE fetching — the lineage gate needs it.
for r in ~/.config/zsh ~/my ~/.config/nvim; do
  echo "$r $(git -C "$r" rev-parse origin/main)"
done
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git rev-parse origin/main

# Fetch all four, then report: repo · ahead · behind · dirty
# (ahead = origin/main..work, behind = work..origin/main)
```

Dirty repos: adots routinely carries dirty rc/memory files — that is normal,
do NOT sweep. Any other repo dirty → stop and resolve before merging.

---

## Phase 1 — Lineage-continuity gate (EVERY repo, BEFORE any merge)

```bash
# old tip = the pre-fetch origin/main recorded in Phase 0
git -C <repo> merge-base --is-ancestor <old-tip> origin/main \
  && echo "lineage continuous" || echo "HISTORY REWRITE — do not merge"
```

- **Continuous** → Phase 2 (normal merge).
- **Rewrite** → Phase R (rewrite protocol). A normal merge would re-introduce
  purged commits and can re-push removed content. Never merge across a rewrite.

---

## Phase R — History-rewrite protocol (replaces merge for that repo)

1. **Read the tip guidance first**: check the new tip commit and repo root for
   `UPGRADING.md`/README notes — the rewriter usually documents intent
   (what was purged, old→new tip mapping).
2. **Compute the unpushed local delta**: `git diff --binary <old-main-tip> work`
   (`--binary` or icons/assets fail to apply). Confirm the delta's paths do not
   intersect the purged paths (`git diff --name-only origin/main <old-main-tip>`).
   Any overlap → STOP, operator decision.
3. **Rebuild**: `git switch -C work origin/main`, apply the delta
   (`git apply --index`), commit with a message referencing the original SHAs;
   cherry-pick any plain commits that sit above the old merge.
4. **Verify byte-exact**: `git diff work <old-work-tip>` must equal exactly the
   purge delta — zero drift in the paths your delta touched.
5. **Purge the old lineage locally** (the rewrite is pointless if old refs
   survive): re-snap `main`, then
   `git reflog expire --expire=now --all && git gc --prune=now`.
   Confirm: `git cat-file -e <old-tip>` now fails.
6. **Audit exports**: old-lineage artifacts survive outside the repo — check
   `~/Desktop/outbox/` patches, worktrees, and second clones; report each to
   the operator (they may contain the purged content).

---

## Phase 2 — Merge (continuous lineage only)

`git merge origin/main` on `work`. One merge attempt; if it goes sideways,
`git merge --abort` and report. Conflict resolution policy:

| Conflict class | Winner | Why |
|---|---|---|
| Machine-specific files: launchd plists (absolute paths, sockets), host names (`.localhost` vs `.local`), Ruby/tool version pins, endpoints | **work side** | The other machine's paths/pins break this machine |
| Functional superset (one side added a feature the other lacks) | superset side | Then verify referenced routes/columns/classes exist post-merge |
| Deliberate recorded values (a11y contrast/headings, redirect-blind checks) | the side whose commit message records the rationale | Check `git log -1 <side> -- <file>` |
| Generated files (Gemfile.lock, package-lock.json) | take main, then regenerate (`bundle install` etc.) and stage | Hand-merging lockfiles is a lie |
| Both sides re-landed the same intent (add/add) | assemble manually | Expect this after home `git am`s exported patches — SHAs differ, content half-matches |

Post-merge sweeps (auto-merge lies silently):
- `grep -rn '^<<<<<<<\|^>>>>>>>'` over changed files — no markers survive.
- Duplicate-block scan on routes/config files both sides appended to
  (duplicate Rails route names abort boot).
- If a Rails app was touched: `bin/rails zeitwerk:check`.
  **Never run a repo's test suite as validation until its test-DB isolation is
  verified** (`current_database()` must end `_test` — see the 2026-07-21
  spec-suite-wrote-to-production incident).

---

## Phase 3 — Backlog ID collision scan (zdots, until Z-245 lands)

Both machines allocate the next sequential Z-nnn independently; concurrent
filings collide (happened twice: Z-235/236 on 07-20, Z-240 on 07-21).

```bash
# Full ID token only — z-172 and its subtask z-172.03 are distinct IDs, not a dup.
ls ~/.config/zsh/backlog/tasks/ | sed -E 's/^(z-[0-9]+(\.[0-9]+)?) - .*/\1/' | sort | uniq -d
# PASS: no output
# FAIL: upstream's ID is canonical (already in main's history). Renumber the
#       LOCAL task to the next free ID: update `id:` frontmatter, `git mv` the
#       file, commit. Never renumber upstream's.
```

---

## Phase 4 — Post-merge reconciliation (per repo, from the merge diff)

```bash
git diff ORIG_HEAD..origin/main --name-only | grep -E \
  'db/migrations|phi-patterns|svc-registry|otel-collector|llama|lib/zdots/jobs|Brewfile'
```

| Path touched | Action |
|---|---|
| `db/migrations/` | `zdots-ctx migrate` |
| `etc/phi-patterns.yaml` | note: shell restart recommended |
| `lib/svc-registry.bash` | `zdots-ctl reset` |
| llama plists | `zsvc restart llama; zsvc restart embed` |
| `etc/otel-collector.yaml` | `zsvc restart otel` |
| `lib/zdots/**` or `sbin/zdots-brain` | `zsvc restart worker` — a long-lived worker keeps running OLD code silently (found running 6-day-old code on 07-21) |
| `Brewfile.*` | `zdots-update-local --dry-run`, then targeted run |

Then re-snap every repo's local `main`: `git branch -f main origin/main`.

---

## Phase 5 — Validate + report

`zdots doctor --no-runtime --quiet` and `zdots-ctl check` must pass.

Report: 4-row table (repo · ahead/behind · merged/rewritten/no-op · conflicts
resolved), reconciliation actions taken, and the push commands for the
operator — pushes are theirs:

```bash
git -C ~/.config/zsh push -u origin work
git -C ~/my push -u origin work
git -C ~/.config/nvim push -u origin work
env GIT_DIR=$HOME/.homegit GIT_WORK_TREE=$HOME git push -u origin work
```

(Home deletes `origin/work` after integrating — a fetch showing
`[deleted] origin/work` is the loop working, not an error; `push -u`
recreates it.)

---

## Hard limits

- Never merge across a history rewrite; never `git pull --force` or reset
  `work` without the rewrite protocol.
- Never `git add -A` — stage exact paths (`bin/secret-scan` before commits).
- One merge attempt per repo per run; a failed second attempt is an operator item.
- ≥10 conflicts in one repo → do the analysis in an isolated worktree (or
  delegate to a merge-resolver agent) instead of churning the live tree.
- Do not push. Do not integrate `work`→`main` here — that is home-side.
