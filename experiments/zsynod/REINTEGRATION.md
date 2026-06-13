# zsynod Reintegration Guide
Created: 2026-06-13

zsynod was fully contained into this directory. Nothing from the previous
integration points remains in the repo root. This file documents what was
where and what to do when you want to re-promote zsynod to a first-class
Platform Service.

---

## What Was Moved Here

| Original path | Now at | Notes |
|---------------|--------|-------|
| `bin/zsynod_tui.py` | `experiments/zsynod/bin/zsynod_tui.py` | Python TUI; was not executable |
| `bin/zsynod-migrate` | `experiments/zsynod/bin/zsynod-migrate` | Ledger migration (Bash-JSONL → Python-Pydantic) |
| `lib/zsynod_core.py` | `experiments/zsynod/lib/zsynod_core.py` | Core ledger + member + session logic |
| `lib/zsynod_otel.py` | `experiments/zsynod/lib/zsynod_otel.py` | OTel tracing for zsynod |
| `functions/enabled/_zsynod` | `experiments/zsynod/functions/_zsynod` | Zsh completion function |
| `man/man1/zsynod.1` | `experiments/zsynod/man/man1/zsynod.1` | Man page |
| `share/man/man1/zsynod.1` | `experiments/zsynod/share/man/man1/zsynod.1` | Duplicate man page |
| `tests/zsynod_core_py.bats` | `experiments/zsynod/tests/` | Unit tests for zsynod_core.py |
| `tests/zsynod_exectick.bats` | `experiments/zsynod/tests/` | Exec-tick tests |
| `tests/zsynod_headless.bats` | `experiments/zsynod/tests/` | Headless session tests |
| `tests/zsynod_init.bats` | `experiments/zsynod/tests/` | Init lifecycle tests |
| `tests/zsynod_launch.bats` | `experiments/zsynod/tests/` | Launch/facilitator tests |
| `tests/zsynod_minutes.bats` | `experiments/zsynod/tests/` | Minutes recording tests |
| `tests/zsynod_queue.bats` | `experiments/zsynod/tests/` | Queue tests |
| `tests/zsynod_repl.bats` | `experiments/zsynod/tests/` | REPL tests |
| `tests/zsynod_risk.bats` | `experiments/zsynod/tests/` | Risk flag tests |
| `tests/zsynod_tick.bats` | `experiments/zsynod/tests/` | Tick/pulse tests |

---

## Integration Points That Existed (Unwired)

These are the connections that existed when zsynod was integrated into zdots.
Each one needs to be re-established when promoting zsynod.

### 1. Shell completion — `functions/enabled/_zsynod`

**What it was:** A zsh `#compdef zsynod` completion function auto-loaded by zdots
from `functions/enabled/`. It provided tab completion for all zsynod subcommands
with dynamic proposal/queue/member IDs.

**To re-enable:** Symlink or copy back to `functions/enabled/_zsynod`. The
`functions/enabled/` directory is sourced by the shell startup sequence.

```bash
ln -sf "$ZDOTDIR/experiments/zsynod/functions/_zsynod" "$ZDOTDIR/functions/enabled/_zsynod"
```

### 2. Man page — `man/man1/zsynod.1` + `share/man/man1/zsynod.1`

**What it was:** Two copies of the man page in `man/man1/` and `share/man/man1/`
(the latter for Homebrew-style prefix installation). The `man/` path is in `MANPATH`.

**To re-enable:** Symlink back to `man/man1/`:

```bash
ln -sf "$ZDOTDIR/experiments/zsynod/man/man1/zsynod.1" "$ZDOTDIR/man/man1/zsynod.1"
```

Determine whether `share/man/man1/` is needed (likely redundant with `man/man1/`).

### 3. Python modules — `lib/zsynod_core.py` + `lib/zsynod_otel.py`

**What they were:** Python modules imported by `bin/zsynod_tui.py` and the bats
tests. `lib/` is a mixed bash/Ruby library directory; Python modules were
architecturally inconsistent there.

**To re-enable (cleaner):** Import directly from the experiment path, or add
`experiments/zsynod/lib` to `PYTHONPATH` when running zsynod:

```bash
export PYTHONPATH="$ZDOTDIR/experiments/zsynod/lib:${PYTHONPATH:-}"
```

Or in `experiments/zsynod/bin/zsynod`, source the lib from a relative path.

### 4. bin/ commands — `bin/zsynod_tui.py` + `bin/zsynod-migrate`

**What they were:** On PATH via `bin/`. `zsynod_tui.py` was not executable
(needed `python3 zsynod_tui.py`). `zsynod-migrate` was executable.

**To re-enable:** Symlink into `bin/` or add `experiments/zsynod/bin` to PATH:

```bash
# Option A: symlinks
ln -sf "$ZDOTDIR/experiments/zsynod/bin/zsynod-migrate" "$ZDOTDIR/bin/zsynod-migrate"
# Option B: PATH extension (add to .zdots.local)
export PATH="$ZDOTDIR/experiments/zsynod/bin:$PATH"
```

### 5. Tests — `tests/zsynod_*.bats` (10 files)

**What they were:** Part of the main bats test suite run by `bats tests/` or
`make test`. They used `setup.bash` / `REPO_ROOT` for path resolution, so many
references like `$BIN/zsynod_core.py` or `$REPO_ROOT/lib/zsynod_core.py` will
now resolve incorrectly relative to the experiment directory.

**To re-enable:**
1. Copy or symlink tests back into `tests/`
2. Update `REPO_ROOT` references in each test to point at `experiments/zsynod/`
   for zsynod-specific files, while using `$REPO_ROOT` for shared fixtures

Or create a wrapper:
```bash
REPO_ROOT="$ZDOTDIR" ZSYNOD_ROOT="$ZDOTDIR/experiments/zsynod" bats experiments/zsynod/tests/
```

### 6. Open backlog tasks

These tasks remain in the main backlog and reference zsynod work:
- Z-136: zsynod-init emits jq stderr on fresh ZSYNOD_DIR
- Z-137: Wire OpenCode into zsynod launch facilitator
- Z-138: zsynod-minutes markdown heading injection
- Z-142: Automated test gate for zsynod ratchet
- Z-143: Librarian member (contextual continuity)
- Z-144: Cross-platform sync

---

## Running zsynod While Contained

The main binary is at `experiments/zsynod/bin/zsynod`. Run directly:

```bash
cd "$ZDOTDIR/experiments/zsynod"
PYTHONPATH="./lib" python3 bin/zsynod_tui.py   # TUI
bin/zsynod init                                 # init
bin/zsynod tick                                 # pulse tick
```

Run tests from the experiment directory:

```bash
bats experiments/zsynod/tests/
```

---

## Promotion Checklist (when ready)

- [ ] Decide: Python lib placement — `lib/` (mixed) or `experiments/zsynod/lib/` only
- [ ] Relink `functions/enabled/_zsynod` for shell completion
- [ ] Relink `man/man1/zsynod.1` (consolidate to one man page)
- [ ] Add `bin/zsynod-migrate` and `bin/zsynod-tui` symlinks or PATH entry
- [ ] Update `tests/zsynod_*.bats` REPO_ROOT references
- [ ] Add zsynod to `zdots-ctl` service registry if it becomes a Platform Service
- [ ] Add zsynod to `agent-guide` and `capabilities` output
- [ ] Add zsynod to `docs/tooling.md`
- [ ] Add to `AGENTS.md` service table
- [ ] File ADR-0003 documenting the architecture decision
