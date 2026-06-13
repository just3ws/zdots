# Audit: zsynod
Generated: 2026-06-13
Agent: main-session

---

## Location Summary

Expected location: `experiments/zsynod/`
Actual state: **zsynod is distributed across production paths** — it has outgrown the experiment namespace.

### Files at expected location (`experiments/zsynod/`)
```
experiments/zsynod/bin/zsynod        ← main binary
experiments/zsynod/CHARTER.md
experiments/zsynod/DECISIONS.md
experiments/zsynod/GLOSSARY.md
experiments/zsynod/GLYPHS.md
experiments/zsynod/LIFECYCLE.md
experiments/zsynod/STRATEGY.md
experiments/zsynod/TUTORIAL.md
experiments/zsynod/ZEN.md
experiments/zsynod/README.md
experiments/zsynod/agenda.md
experiments/zsynod/dials.json
experiments/zsynod/ledger.jsonl
experiments/zsynod/ledger.py.jsonl
experiments/zsynod/members.json
experiments/zsynod/minutes.md
experiments/zsynod/queue/
experiments/zsynod/sessions/
experiments/zsynod/transcripts/
```

### Files OUTSIDE expected location (production paths)

| Path | Finding |
|------|---------|
| `bin/zsynod_tui.py` | Python TUI — NOT executable, in bin/ — misplaced |
| `bin/zsynod-migrate` | Migration script in bin/ |
| `bin/__pycache__/zsynod_tui.cpython-314.pyc` | Python bytecode in bin/ — pollutes bin/ |
| `lib/zsynod_core.py` | Python module — in lib/ alongside bash libs |
| `lib/zsynod_otel.py` | OTel Python module — same issue |
| `functions/enabled/_zsynod` | Shell completion/function — may be intentional |
| `man/man1/zsynod.1` | Man page — appropriate for a real command |
| `share/man/man1/zsynod.1` | Duplicate man page (also in man/man1/) |
| `tests/zsynod_core_py.bats` | Bats test for Python module |
| `tests/zsynod_exectick.bats` | Bats test |
| `tests/zsynod_headless.bats` | Bats test |
| `tests/zsynod_init.bats` | Bats test |
| `tests/zsynod_launch.bats` | Bats test |
| `tests/zsynod_minutes.bats` | Bats test |
| `tests/zsynod_queue.bats` | Bats test |
| `tests/zsynod_repl.bats` | Bats test |
| `tests/zsynod_risk.bats` | Bats test |
| `tests/zsynod_tick.bats` | Bats test (10 total) |
| `experiments/enable-zsynod.sh` | Enable script |

### .claude/worktrees/ (stale agent worktrees — not main branch)
Two orphaned worktrees (`agent-a926184c9c04e2581`, `agent-aa1d122122760da74`) both contain full zsynod trees. These are from previous timed-out agent runs and should be pruned with `git worktree prune`.

---

## Findings

## bin/zsynod_tui.py
Status: relocate_candidate
Confidence: high
Risk: low
### Evidence
- Direct references: None found in startup or docs
- Executable: NO — only non-executable file in bin/
- PATH / startup involvement: bin/ is on PATH but `.py` extension and non-executable means it won't run as `zsynod_tui`
- Git history notes: Added with other zsynod work
- Related: `bin/__pycache__/zsynod_tui.cpython-314.pyc` proves it was imported somewhere
### Recommendation
relocate_candidate → `experiments/zsynod/bin/` or `experiments/zsynod/`
### Rationale
Non-executable Python file in bin/ won't run from PATH. `__pycache__` pollutes bin/. If this is the TUI for the zsynod experiment, it belongs with the rest of experiments/zsynod/.
### Future commit plan
No commit during dry run. If approved: `git mv bin/zsynod_tui.py experiments/zsynod/` + remove `__pycache__`.

---

## bin/__pycache__/ (zsynod_tui.cpython-314.pyc)
Status: delete_candidate
Confidence: high
Risk: low
### Evidence
- Python bytecode cache generated when zsynod_tui.py was run from bin/
- Should never be committed or present in bin/
- `.gitignore` should exclude `__pycache__/` — check if it does
### Recommendation
delete_candidate — bytecode cache does not belong in bin/
### Rationale
`__pycache__` in bin/ is pure pollution. Moving zsynod_tui.py will resolve this.
### Future commit plan
No commit during dry run. Remove with `git rm -r bin/__pycache__` if tracked; `rm -rf` if not.

---

## lib/zsynod_core.py + lib/zsynod_otel.py
Status: needs_human_review
Confidence: medium
Risk: medium
### Evidence
- Python modules in `lib/` alongside bash lib files
- `__pycache__` in `lib/` (from imports)
- Referenced by `tests/zsynod_core_py.bats` — so actively tested
- 10 zsynod test files suggest these are used
### Recommendation
needs_human_review
### Rationale
`lib/` convention in zdots is bash library files (e.g., `lib/phi_scrubber.bash`). Python modules here are architecturally inconsistent. But they ARE tested and actively used. Decision: should lib/ host Python, or should zsynod Python live under `experiments/zsynod/lib/`? Operator must decide.
### Future commit plan
No commit during dry run. Requires operator architecture decision.

---

## man/man1/zsynod.1 + share/man/man1/zsynod.1
Status: keep_with_note
Confidence: medium
Risk: low
### Evidence
- Man pages = evidence of intent to treat zsynod as a real command
- Duplicate: same man page in both `man/man1/` and `share/man/man1/`
### Recommendation
keep_with_note — deduplicate to one location
### Rationale
One of these is a symlink target, the other may be redundant. Needs operator to verify which path is authoritative.

---

## functions/enabled/_zsynod
Status: needs_human_review
Confidence: medium
Risk: medium
### Evidence
- Shell function in `functions/enabled/` — auto-loaded by zdots shell startup
- Prefix `_` suggests completion function or private helper
- Shell startup is a sacred area
### Recommendation
needs_human_review — startup involvement makes this sacred
### Rationale
If `_zsynod` is a zsh completion function, it's correctly placed. If it's something else, needs review. Touching shell startup without understanding this is risky.

---

## Open Backlog Tasks (zsynod)

| ID | Title | Risk |
|----|-------|------|
| Z-136 | zsynod-init emits jq stderr on fresh ZSYNOD_DIR | medium |
| Z-137 | Wire OpenCode into zsynod launch | low |
| Z-138 | zsynod-minutes markdown heading injection | low |
| Z-142 | Bridge verification gap — automated test gate | low |
| Z-143 | Bridge contextual continuity gap — Librarian member | low |
| Z-144 | Bridge physical machine gap — cross-platform sync | low |

6 open zsynod tasks. None are P0. All medium/low risk.

---

## Overall Assessment

zsynod has **graduated beyond an experiment**. It has:
- 10 bats test files
- Man pages
- Shell function in startup path
- Python modules in lib/
- Active open backlog tasks
- A full directory in experiments/ with charter, ledger, and session history

**The expected "experiments/zsynod" destination is outdated.** The real question is whether to:
1. Formalize zsynod as a first-class platform capability (move out of experiments/, clean up lib/ Python placement)
2. Keep it in experiments/ but move stray files back (bin/zsynod_tui.py, lib/*.py)

Recommended: **create_backlog_task** for architecture decision on zsynod promotion status.

Concrete low-risk action: move `bin/zsynod_tui.py` to `experiments/zsynod/` and clean `bin/__pycache__/`.

### Orphaned worktrees
`.claude/worktrees/agent-a926184c9c04e2581` and `agent-aa1d122122760da74` are stale agent worktrees from timed-out subagent runs (this audit session). Run `git worktree list` and `git worktree prune` to clean.
