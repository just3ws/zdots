# Regrounding the Practice

A recovery and regrounding plan for Zdots — restoring disciplined practice to a project that describes rigor but has drifted from it.

## Problem Statement

Zdots has ambitious architecture (DDD, SOLID, DI, Observability) and a compelling narrative (the SAGA). But the project's own quality standards are not being upheld:

- `make check` fails on the current working tree
- 21 of 21 "Done" tasks have unchecked Definition of Done
- 2 tasks are marked Done with unfinished acceptance criteria (Z-011, Z-019)
- Decision-005 is accepted with empty Context, Decision, and Consequences
- Zero milestones exist despite 21 completed tasks
- Zero tasks archived to `completed/`
- Known CI fixes (fzf/zle, secret-scan) were diagnosed but never applied
- Uncommitted changes to `.zshrc` introduced the check regression
- Ephemeral telemetry data (`traces-collected.json`) is tracked in git

The foundation is telling the truth about its instability. The practice must be regrounded before forward work can be trusted.

## Approach

**Foundation First** — Treat the recovery as earning Milestone 1. Five sequential steps, each verified before the next proceeds. The recovery itself is the first act of discipline.

## Milestones

Three milestones map to the SAGA's three eras. A fourth marks the horizon. Each has a gate — an objective, verifiable condition. No ambiguity, no judgment calls.

### Milestone 1: Interchangeable Parts

*"The foundation is solid and green."*

**Gate:**
- `make check` exits 0
- All tasks assigned to this milestone have all ACs checked, all DoD checked, and a final summary
- No uncommitted functional changes on main

**Scope:** POSIX core, providers, shell safety, caching, benchmarking, basic testing framework, documentation of architecture and philosophy. The work that makes Zdots a reliable, modular shell configuration that adapts to its host.

**Tasks:** Z-001, Z-002, Z-003, Z-004, Z-007, Z-008, Z-011, Z-015, Z-016, Z-017, Z-018, plus recovery tasks from the sequence below.

### Milestone 2: Radical Observability

*"The shell sees itself."*

**Gate:**
- Milestone 1 is closed
- `bin/trace-verify` passes
- Heartbeat spans are emitted and verifiable
- The LGTM stack can receive and display traces from a live shell session

**Scope:** Observability control plane, distributed tracing, OTLP routing, OTel collector, LGTM stack, security hardening of telemetry, self-describing capabilities.

**Tasks:** Z-005, Z-006, Z-009, Z-014, Z-022, Z-023, Z-024

### Milestone 3: Engineered Intelligence

*"The shell learns."*

**Gate:**
- Milestones 1 and 2 are closed
- `bin/history-analyze --ai` produces actionable output from live traces
- AI providers respond to health checks
- Multi-environment (Mac + Pi) is demonstrated

**Scope:** AI inference providers, history analysis, model management, Gemini integration, cross-platform injection, log management, disk optimization.

**Tasks:** Z-010, Z-012, Z-013, Z-019, Z-020, Z-021, Z-025, Z-026, Z-027

### Milestone 4: The Second Brain

*"The environment knows itself and its owner."*

**Gate:** Not yet defined. This milestone is intentionally left as a heading with principles, not acceptance criteria. The learning is the point.

**Principles:**
- **POSIX-driven central truth.** The shell becomes a central nervous system for the environment — not just configuration, but identity, discovery, and coordination.
- **XDG as the skeleton.** Convention over configuration. Directories mean things. `~/.config`, `~/.local`, `~/.cache` are load-bearing, not suggestions.
- **`~/my` as the brain.** A structured knowledge layer — the human-facing complement to the shell's machine-facing control plane. Plain files, FOSS tools, vim-native. Not Obsidian. Not ecosystem lock-in.
- **shellcheck + TDD as the immune system.** Every convention is tested. Every assumption is verified. The shell defends its own integrity.
- **Kaizen.** Continuous improvement earned through practice. Single-threaded human+AI working sessions build trust and muscle memory. Agentic autonomy is earned, not granted. Each step teaches.
- **FOSS-native.** Tools that respect the user's autonomy. No brand-blur. Podman over Docker when it matters. Plain text over proprietary formats. The AI serves the human's preferences and system, not the other way around.

## Recovery Sequence

Five steps. Strictly sequential. Each becomes a backlog task assigned to Milestone 1. No step proceeds until the previous one is verified.

### Step 1: Get Clean

*Resolve the uncommitted state. Establish ground truth.*

**Work:**
1. Add `traces-collected.json` to `.gitignore`
2. Stage and commit all three changes together: `.gitignore` update, `.iterm2_shell_integration.zsh` upstream update (whitespace, typo fix), `.zshrc` iTerm2 sourcing (intentional change, regression addressed in Step 2)
3. One commit: this is cleanup, not three independent features

**Verification:** `git status` shows no modified or untracked files that should be tracked.

### Step 2: Get Green

*Fix the regression suite. Nothing else matters until the ground is solid.*

Four known failures, fixed in order:

1. **iTerm2 escape sequence pollution.** `bin/check` history mode assertions fail because iTerm2 shell integration injects OSC escape sequences into captured `zsh -i -c` output, breaking `grep -qx` exact-line matches. Fix: strip ANSI/OSC sequences from captured output before assertions, or suppress integration during check by unsetting `ITERM_SHELL_INTEGRATION_INSTALLED`.
2. **fzf/zle error.** `fzf` key-bindings.zsh attempts to restore the `zle` option in non-tty contexts via `eval`. Fix: guard fzf sourcing with `[[ -o zle ]]` check, or filter the known stderr message in `bin/check`.
3. **secret-scan self-matching.** `bin/secret-scan` patterns match their own definitions in the script file. `set -e` causes termination on first no-match from `run_scan`. Fix: exclude `bin/secret-scan` from scan scope. Add `|| true` to `run_scan` invocation.
4. **Bats conditional execution.** Tests silently skip if `bats` is not installed. Fix: emit a visible warning when `bats` is absent. Ensure CI runner dependencies include `bats-core`.

**Verification:** `make check` exits 0. `bin/secret-scan` exits 0. Full output captured in commit message.

### Step 3: Get Honest

*Reconcile every Done task against its acceptance criteria.*

For each of the 21 Done tasks:
- **All ACs genuinely met in code:** Check the AC boxes via CLI. Check the DoD box. Write a final summary if missing.
- **AC met but box not checked** (e.g., Z-019 AC#5): Check the box. The work exists; the tracking was missed.
- **AC not met and work not done** (e.g., Z-011 AC#2, AC#3): Either re-open the task and reduce its scope to what was delivered, or split unfinished ACs into new tasks assigned to the appropriate milestone.

**Known reconciliations:**
- **Z-011:** Split. AC#1 (zdots_safe_source) is done — mark it, write a final summary, close with reduced scope. AC#2 (ZDOTS_SAFE_MODE) and AC#3 (timeout protection) become new tasks in Milestone 1.
- **Z-019:** Check AC#5. `bin/history-analyze` uses `zdots_ai_infer`. The checkbox was missed.
- **Decision-005:** Fill Context, Decision, and Consequences from what was actually built (providers/ai/*, conf.d/95-ai.zsh), or retract it as premature if the decision has not truly been made.

**Verification:** No task marked Done has unchecked ACs. Every Done task has DoD checked and a final summary. `backlog task list --plain` confirms.

### Step 4: Get Structured

*Create milestones. Assign every task. Archive what is earned.*

**Work:**
1. Create three milestones: `Interchangeable Parts`, `Radical Observability`, `Engineered Intelligence`
2. Assign every task (Done and To Do) to its milestone per the mapping above
3. Archive all honestly-Done tasks via `backlog task archive`
4. Ensure remaining To Do tasks are correctly prioritized within their milestone

**Verification:** `backlog milestone list` shows three milestones with task counts. `backlog/completed/` or `backlog/archive/tasks/` contains archived tasks. Active task list shows only open work.

### Step 5: Get Disciplined

*Codify the gate so the way is not lost again.*

**Work:**
1. Update `backlog/config.yml` Definition of Done defaults:
   - All acceptance criteria checked with evidence
   - `make check` passes (output captured in task notes or commit)
   - No uncommitted functional changes related to this task
2. Add **Task Completion Protocol** section to `AGENTS.md`:
   - No task is Done until: every AC is checked with evidence, `make check` passes with captured output, all DoD items are checked, a final summary is written, all related changes are committed
   - No milestone closes until: all assigned tasks satisfy the above, the milestone gate condition is verified with captured output, SAGA.md is updated
3. Update decision-002 to reference the new DoD and milestone gates
4. Update SAGA.md to acknowledge the recovery — what was found, what was restored, what was learned

**Verification:** `backlog/config.yml` reflects the new DoD. `AGENTS.md` contains the Task Completion Protocol with zero ambiguity. Decision-002 references the enforceable gates.

## The Ongoing Practice

After recovery, every task follows this lifecycle. No exceptions for any agent — Claude, Gemini, or the human at the keyboard.

### Task Lifecycle

```
To Do
  -> In Progress (claim it, assign yourself, write implementation plan)
  -> Work (one AC at a time, check each with evidence)
  -> Verify (make check passes, DoD checked, final summary written, git clean)
  -> Done
```

**One task at a time.** No task is started while another is In Progress for the same milestone. This prevents the drift that created 21 Done tasks with unchecked boxes.

**Evidence before assertions.** When you check an AC, the commit message or task notes reference what you ran and what it output. "I believe it works" is not evidence. `make check` output is evidence.

### Milestone Closure

Each milestone has a formal close:

1. All tasks assigned to the milestone are Done with full verification
2. The milestone gate condition is verified and output is recorded
3. The milestone is archived in the backlog
4. SAGA.md is updated to reflect the passage — what was learned, what was earned

An agent cannot begin work on Milestone N+1 tasks while Milestone N has unverified open tasks. The milestones are sequential. The path is forward.

### Kaizen

The practice itself evolves. After each milestone closure, review what worked and what didn't. Update the Task Completion Protocol if needed. The spec is a living document — but changes are earned through practice, not decreed in advance.
