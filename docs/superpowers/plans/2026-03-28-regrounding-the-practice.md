# Regrounding the Practice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore disciplined practice to Zdots by earning the right to close Milestone 1 through five sequential, verified recovery steps.

**Architecture:** Five sequential tasks, each with concrete verification gates. No task proceeds until the previous one's verification passes. Recovery tasks become backlog items assigned to Milestone 1: Interchangeable Parts.

**Tech Stack:** Zsh, POSIX sh, Bats-core, backlog CLI, git, make

**Spec:** `docs/superpowers/specs/2026-03-28-regrounding-the-practice-design.md`

---

## Task 1: Get Clean

*Resolve the uncommitted state. Establish ground truth.*

**Files:**
- Modify: `.gitignore`
- Commit (as-is): `.zshrc`
- Commit (as-is): `.iterm2_shell_integration.zsh`

- [ ] **Step 1: Add ephemeral telemetry file to .gitignore**

Append to `.gitignore`:

```
# Ephemeral telemetry data
traces-collected.json
```

- [ ] **Step 2: Unstage and reset the ephemeral file from tracking**

Run: `git rm --cached traces-collected.json`
Expected: `rm 'traces-collected.json'`

- [ ] **Step 3: Verify the working tree is ready to commit**

Run: `git status`
Expected: `.gitignore` modified, `traces-collected.json` deleted from index, `.zshrc` modified, `.iterm2_shell_integration.zsh` modified. No surprises.

- [ ] **Step 4: Stage all cleanup changes**

```bash
git add .gitignore .zshrc .iterm2_shell_integration.zsh
```

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore: clean working tree and gitignore ephemeral telemetry

- Add traces-collected.json to .gitignore (ephemeral OTel data)
- Remove traces-collected.json from git tracking
- Commit .zshrc iTerm2 shell integration sourcing (regression addressed in next commit)
- Commit .iterm2_shell_integration.zsh upstream update (whitespace, typo fix)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Verify ground truth**

Run: `git status`
Expected: `nothing to commit, working tree clean` (traces-collected.json may appear as untracked but is gitignored).

---

## Task 2: Get Green

*Fix the regression suite. Four known failures, fixed in order.*

**Files:**
- Modify: `bin/check:75-106` (history mode assertions)
- Modify: `bin/check:29-50` (stderr filtering)
- Modify: `bin/check:348-351` (bats conditional)
- Modify: `bin/secret-scan:56-58` (self-matching)

### Fix 1: iTerm2 escape sequence pollution in history mode assertions

- [ ] **Step 1: Run the failing test to capture current output**

Run: `SKIP_EXTERNAL=1 make check 2>&1 | head -20`
Expected: Failure at `check: expected share_history in shared mode`. Debug output shows iTerm2 OSC sequences (`]1337;...`) prepended to the `share:on` line.

- [ ] **Step 2: Write the fix — strip OSC/ANSI sequences from captured output**

In `bin/check`, the `assert_history_mode` function captures shell output via `zsh -i -c '...'`. iTerm2 shell integration injects OSC escape sequences into this output. Add a stripping function near the top of the file (after line 6) and apply it to the captured flags.

Add after line 6 (`setopt nonomatch`):

```zsh
# Strip ANSI/OSC escape sequences from captured shell output.
# iTerm2 shell integration injects OSC 1337 sequences that pollute
# output captured via `zsh -i -c '...'`.
_strip_escapes() {
  sed $'s/\x1b\][^\x07]*\x07//g; s/\x1b\\[[0-9;]*[a-zA-Z]//g'
}
```

Then in `assert_history_mode` (line 80-83), pipe the captured output through the filter. Replace:

```zsh
  flags="$(ZDOTS_SHARE_HISTORY="$share_flag" zsh -i -c '
    [[ -o share_history ]] && echo "share:on" || echo "share:off"
    [[ -o inc_append_history_time ]] && echo "inc_append_history_time:on" || echo "inc_append_history_time:off"
  ')"
```

With:

```zsh
  flags="$(ZDOTS_SHARE_HISTORY="$share_flag" zsh -i -c '
    [[ -o share_history ]] && echo "share:on" || echo "share:off"
    [[ -o inc_append_history_time ]] && echo "inc_append_history_time:on" || echo "inc_append_history_time:off"
  ' | _strip_escapes)"
```

- [ ] **Step 3: Run the history mode assertions to verify the fix**

Run: `SKIP_EXTERNAL=1 make check 2>&1 | head -20`
Expected: No `expected share_history` failure. Script progresses past line 109.

### Fix 2: fzf/zle stderr noise

- [ ] **Step 4: Verify the zle error is non-fatal (already filtered)**

Read `bin/check` lines 43-48. The existing filter `grep -vE "can't change option: zle"` already handles this. Confirm it works:

Run: `SKIP_EXTERNAL=1 make check 2>&1 | grep "zle"`
Expected: The `(eval):1: can't change option: zle` message appears in debug output but does NOT cause a failure (it is filtered on lines 43 and 66).

If this is already passing, no code change needed. Move to Fix 3.

### Fix 3: secret-scan self-matching

- [ ] **Step 5: Run secret-scan to capture current behavior**

Run: `bin/secret-scan`
Expected: Either `secret-scan: OK` (already fixed per line 64 exclusion) or a false positive from high-confidence patterns matching their own definitions.

- [ ] **Step 6: If secret-scan fails — add self-exclusion for high-confidence patterns**

The broad pattern already excludes `bin/secret-scan:` (line 64). But the high-confidence pattern loop (lines 56-58) does not. If step 5 fails, modify the `run_scan` function to exclude the scan script itself. Replace lines 47-49:

```bash
    git ls-files -z | xargs -0 rg -H -n -i "${extra_args[@]}" "$pattern" >>"$out_file" 2>/dev/null || true
```

With:

```bash
    git ls-files -z | xargs -0 rg -H -n -i "${extra_args[@]}" "$pattern" 2>/dev/null | \
      rg -v '^bin/secret-scan:' >>"$out_file" 2>/dev/null || true
```

And the grep fallback (line 51):

```bash
    git ls-files -z | xargs -0 grep -H -n -i -E "${extra_args[@]}" "$pattern" 2>/dev/null | \
      grep -v '^bin/secret-scan:' >>"$out_file" 2>/dev/null || true
```

- [ ] **Step 7: Verify secret-scan passes**

Run: `bin/secret-scan`
Expected: `secret-scan: OK`

### Fix 4: Bats conditional execution

- [ ] **Step 8: Make bats absence visible instead of silent**

In `bin/check`, replace lines 348-351:

```zsh
  if command -v bats >/dev/null 2>&1; then
    echo "check: running Bats tests..."
    bats tests/
  fi
```

With:

```zsh
  if command -v bats >/dev/null 2>&1; then
    echo "check: running Bats tests..."
    bats tests/
  else
    echo "check: warning: bats not found — skipping Bats tests (install via: brew install bats-core)" >&2
  fi
```

- [ ] **Step 9: Run the full check suite**

Run: `make check 2>&1`
Expected: `check: OK` at the end. Full output captured.

- [ ] **Step 10: Run secret-scan independently**

Run: `bin/secret-scan`
Expected: `secret-scan: OK`

- [ ] **Step 11: Commit with captured evidence**

```bash
git add bin/check bin/secret-scan
git commit -m "$(cat <<'EOF'
fix: restore regression suite to green

- Strip iTerm2 OSC escape sequences from captured shell output in
  bin/check history mode assertions (root cause of share_history failure)
- Add self-exclusion to bin/secret-scan high-confidence pattern loop
  to prevent false positive on own pattern definitions
- Make bats absence visible with a warning instead of silent skip

Evidence: make check exits 0, bin/secret-scan exits 0

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Get Honest

*Reconcile every Done task against its acceptance criteria.*

**Files:**
- No source files modified. All changes via `backlog` CLI.

**Prerequisite:** `make check` passes (Task 2 verified).

This task requires auditing each Done task. The work is mechanical but must be thorough. For each task, the agent must:

1. Read the task via `backlog task <id> --plain`
2. For each AC, verify the implementation exists (grep, read file, run command)
3. Check the AC via `backlog task edit <id> --check-ac <n>`
4. Check the DoD via `backlog task edit <id> --check-dod 1`
5. Add a final summary if missing via `backlog task edit <id> --final-summary "..."`

### The three known reconciliations

- [ ] **Step 1: Split Z-011 — separate delivered work from unfinished ACs**

Z-011 AC#1 (zdots_safe_source wrapper) is implemented in `env.sh:70-89`. AC#2 (ZDOTS_SAFE_MODE) and AC#3 (timeout protection) are not implemented anywhere.

```bash
# Reduce Z-011 scope to what was delivered
backlog task edit Z-011 --remove-ac 3
backlog task edit Z-011 --remove-ac 2
backlog task edit Z-011 --check-ac 1
backlog task edit Z-011 --check-dod 1
backlog task edit Z-011 --final-summary "Implemented zdots_safe_source in env.sh as a POSIX-compatible circuit breaker wrapper. Modules loaded via conf.d loop in .zshrc are protected from cascading failures. ZDOTS_SAFE_MODE and timeout protection split to separate tasks."

# Create new tasks for the unfinished work
backlog task create "Implement ZDOTS_SAFE_MODE bypass for heavy integrations" \
  -d "When ZDOTS_SAFE_MODE=1, skip non-essential conf.d modules (AI, integrations, heavy completions) to provide a minimal safe shell for debugging. Split from Z-011 AC#2." \
  --ac "ZDOTS_SAFE_MODE=1 zsh -i loads only essential modules (env, prompt, basic options)" \
  --ac "bin/check validates safe mode produces a functional shell" \
  --priority high

backlog task create "Add timeout protection for provider initialization" \
  -d "Wrap zdots_require calls with a timeout mechanism so a hanging provider (e.g., unreachable AI endpoint) does not block shell startup. Split from Z-011 AC#3." \
  --ac "Provider init that exceeds timeout threshold is killed and logged" \
  --ac "Shell startup completes within performance budget even with a hanging provider" \
  --priority medium
```

- [ ] **Step 2: Fix Z-019 — check the missed AC**

Z-019 AC#5 asks for `bin/history-analyze` to use local AI. It does — `bin/history-analyze` calls `zdots_ai_infer` on line 65. The box was never checked.

```bash
backlog task edit Z-019 --check-ac 5
```

- [ ] **Step 3: Fill decision-005**

Decision-005 ("Local LLM Offloading for Shell Intelligence") is accepted but empty. The decision was made — providers/ai/* exists, conf.d/95-ai.zsh loads them, bin/history-analyze consumes them. Fill it with what was actually decided.

```bash
backlog decision edit decision-005 --context "Shell intelligence features (history analysis, log parsing, command suggestions) require LLM inference. Using frontier models (Claude, GPT) for routine shell-level tasks is wasteful and creates an external dependency for basic operations. Local inference keeps the shell self-contained and respects the FOSS-native principle." \
  --decision "Offload routine shell intelligence tasks to local LLM providers (Ollama, llama.cpp) running on the host or local network. Frontier models are reserved for complex reasoning. The AI service uses the same Dependency Injection pattern as other providers: zdots_ai_init() and zdots_ai_infer() contract, configured via ZDOTS_SERVICE_AI in .zdots.env." \
  --consequences "Positive: Shell intelligence works offline. No API costs for routine tasks. Provider-agnostic — switch between Ollama, llama.cpp, or remote with one config change. Negative: Requires local GPU/CPU resources. Model quality is lower than frontier. Initial model download (hydration) adds setup friction."
```

If `backlog decision edit` is not available as a CLI command, edit the decision file directly at `backlog/decisions/decision-005 - Local-LLM-Offloading-for-Shell-Intelligence.md`.

- [ ] **Step 4: Audit and reconcile the remaining 18 Done tasks**

For each task in the Done list (Z-001, Z-002, Z-003, Z-004, Z-005, Z-006, Z-007, Z-008, Z-009, Z-012, Z-014, Z-015, Z-017, Z-018, Z-020, Z-021, Z-022, Z-023, Z-024), perform the verification loop:

1. `backlog task <id> --plain` — read the task
2. For each unchecked AC: verify the implementation exists in code (grep for functions, read files, check config). If it exists, check it. If it does not exist, flag it for splitting (same pattern as Z-011).
3. `backlog task edit <id> --check-dod 1` — check the DoD (make check now passes, satisfying the default DoD)
4. If the task has no final summary, add one describing what was delivered.

This is the most time-intensive step. The agent should process tasks in ID order and report progress.

- [ ] **Step 5: Verify reconciliation is complete**

Run: `backlog task list --plain`
Expected: Every task with status "Done" has all ACs checked and DoD checked. No task marked Done has unchecked boxes.

---

## Task 4: Get Structured

*Create milestones. Assign every task. Archive what is earned.*

**Files:**
- No source files modified. All changes via `backlog` CLI.

**Prerequisite:** Task 3 complete (all Done tasks honestly reconciled).

- [ ] **Step 1: Create the three milestones**

```bash
backlog milestone add "Interchangeable Parts"
backlog milestone add "Radical Observability"
backlog milestone add "Engineered Intelligence"
```

- [ ] **Step 2: Verify milestones exist**

Run: `backlog milestone list`
Expected: Three milestones listed.

- [ ] **Step 3: Assign Milestone 1 tasks**

```bash
# Foundation tasks
backlog task edit Z-001 --milestone "Interchangeable Parts"
backlog task edit Z-002 --milestone "Interchangeable Parts"
backlog task edit Z-003 --milestone "Interchangeable Parts"
backlog task edit Z-004 --milestone "Interchangeable Parts"
backlog task edit Z-007 --milestone "Interchangeable Parts"
backlog task edit Z-008 --milestone "Interchangeable Parts"
backlog task edit Z-011 --milestone "Interchangeable Parts"
backlog task edit Z-015 --milestone "Interchangeable Parts"
backlog task edit Z-016 --milestone "Interchangeable Parts"
backlog task edit Z-017 --milestone "Interchangeable Parts"
backlog task edit Z-018 --milestone "Interchangeable Parts"
```

Also assign the new tasks created in Task 3 Step 1 (ZDOTS_SAFE_MODE, timeout protection) to Interchangeable Parts. Use their IDs as returned by `backlog task create`.

- [ ] **Step 4: Assign Milestone 2 tasks**

```bash
backlog task edit Z-005 --milestone "Radical Observability"
backlog task edit Z-006 --milestone "Radical Observability"
backlog task edit Z-009 --milestone "Radical Observability"
backlog task edit Z-014 --milestone "Radical Observability"
backlog task edit Z-022 --milestone "Radical Observability"
backlog task edit Z-023 --milestone "Radical Observability"
backlog task edit Z-024 --milestone "Radical Observability"
```

- [ ] **Step 5: Assign Milestone 3 tasks**

```bash
backlog task edit Z-010 --milestone "Engineered Intelligence"
backlog task edit Z-012 --milestone "Engineered Intelligence"
backlog task edit Z-013 --milestone "Engineered Intelligence"
backlog task edit Z-019 --milestone "Engineered Intelligence"
backlog task edit Z-020 --milestone "Engineered Intelligence"
backlog task edit Z-021 --milestone "Engineered Intelligence"
backlog task edit Z-025 --milestone "Engineered Intelligence"
backlog task edit Z-026 --milestone "Engineered Intelligence"
backlog task edit Z-027 --milestone "Engineered Intelligence"
```

- [ ] **Step 6: Archive all honestly-Done tasks**

For each Done task, archive it:

```bash
backlog task archive Z-001
backlog task archive Z-002
backlog task archive Z-003
backlog task archive Z-004
backlog task archive Z-005
backlog task archive Z-006
backlog task archive Z-007
backlog task archive Z-008
backlog task archive Z-009
backlog task archive Z-011
backlog task archive Z-012
backlog task archive Z-014
backlog task archive Z-015
backlog task archive Z-017
backlog task archive Z-018
backlog task archive Z-019
backlog task archive Z-020
backlog task archive Z-021
backlog task archive Z-022
backlog task archive Z-023
backlog task archive Z-024
```

Note: Only archive tasks that were honestly reconciled in Task 3. If any task was re-opened or split, do not archive it.

- [ ] **Step 7: Verify structure**

Run: `backlog milestone list`
Expected: Three milestones with task counts.

Run: `backlog task list --plain`
Expected: Only open tasks (To Do, In Progress) remain in the active list. Done tasks are archived.

Run: `ls backlog/archive/tasks/`
Expected: Archived task files present.

---

## Task 5: Get Disciplined

*Codify the gate so the way is not lost again.*

**Files:**
- Modify: `backlog/config.yml:6` (definition_of_done)
- Modify: `AGENTS.md` (add Task Completion Protocol section)
- Modify: `backlog/decisions/decision-002 - Empirical-Validation-Mandate.md`
- Modify: `SAGA.md` (acknowledge the recovery)

- [ ] **Step 1: Update the Definition of Done defaults**

In `backlog/config.yml`, replace line 6:

```yaml
definition_of_done: ["The update ensures a more safe shell experience and verifies there are no functional regressions."]
```

With:

```yaml
definition_of_done: ["All acceptance criteria checked with evidence (command output, file path, or test result)", "make check passes with output captured in task notes or commit message", "All related changes committed — git status clean for files touched by this task"]
```

- [ ] **Step 2: Verify config is valid YAML**

Run: `yq '.' backlog/config.yml`
Expected: Valid YAML output, `definition_of_done` shows three items.

- [ ] **Step 3: Add Task Completion Protocol to AGENTS.md**

Add the following section after the `## Safety & Quality` section (after line 102, before the BACKLOG.MD GUIDELINES):

```markdown
## Task Completion Protocol

This protocol applies to every agent — Claude, Gemini, or the human at the keyboard. There are no exceptions.

### No task is Done until:

1. **Every acceptance criterion is checked.** Each check references evidence: command output, file path, or test result. "I believe it works" is not evidence.
2. **`make check` passes.** Output is captured in the commit message or task notes.
3. **All Definition of Done items are checked.** Use `backlog task edit <id> --check-dod <n>` for each.
4. **A Final Summary is written.** Describes what changed, why, and how it was verified. Use `backlog task edit <id> --final-summary "..."`.
5. **All related changes are committed.** `git status` is clean for files touched by this task.

### No milestone closes until:

1. All assigned tasks satisfy the five conditions above.
2. The milestone gate condition is verified with captured output.
3. `SAGA.md` is updated to record the passage — what was learned, what was earned.

### One task at a time.

A task is claimed by setting it In Progress and assigning yourself. No new task starts while another is In Progress for the same milestone.

### Milestones

| Milestone | Gate |
|-----------|------|
| Interchangeable Parts | `make check` exits 0. All assigned tasks fully verified. No uncommitted functional changes on main. |
| Radical Observability | Milestone 1 closed. `bin/trace-verify` passes. Heartbeat spans emitted and verifiable. LGTM stack receives live traces. |
| Engineered Intelligence | Milestones 1-2 closed. `bin/history-analyze --ai` produces actionable output. AI providers respond to health checks. |
```

- [ ] **Step 4: Update decision-002 to reference the enforceable gates**

In `backlog/decisions/decision-002 - Empirical-Validation-Mandate.md`, add a new section after Consequences:

```markdown
## Enforcement (added 2026-03-28)

This decision is now enforced through the Task Completion Protocol in AGENTS.md and the Definition of Done defaults in backlog/config.yml. Specifically:

- `make check` must pass before any task is marked Done (output captured as evidence)
- Milestone gates formalize the verification scope for each project phase
- The protocol applies to all agents (human and AI) without exception
```

- [ ] **Step 5: Update SAGA.md to acknowledge the recovery**

Add a new section between "The Original Trilogy" and "The Sequel Trilogy":

```markdown
### Interlude: The Regrounding
**"Earned, Not Declared"**

Between the Originals and the Sequels, the project paused to face an uncomfortable truth: the practice had not kept pace with the ambition. Twenty-one tasks were marked Done with unchecked criteria. The regression suite was broken. Milestones existed only in narrative, never in the backlog.

The Regrounding was five steps: Get Clean, Get Green, Get Honest, Get Structured, Get Disciplined. Each step was verified before the next could begin. The recovery itself modeled the discipline it restored.

*   **The Lesson**: A system that describes rigor but does not practice it is more fragile than one that makes no claims at all.
*   **The Gate**: No task is Done without evidence. No milestone closes without verification. The practice is the same regardless of who does the work.
```

- [ ] **Step 6: Verify all changes**

Run: `make check`
Expected: `check: OK`

Run: `yq '.' backlog/config.yml`
Expected: Valid YAML with three DoD items.

Run: `grep -c "Task Completion Protocol" AGENTS.md`
Expected: At least 1 match.

- [ ] **Step 7: Commit**

```bash
git add backlog/config.yml AGENTS.md SAGA.md "backlog/decisions/decision-002 - Empirical-Validation-Mandate.md"
git commit -m "$(cat <<'EOF'
feat: codify Task Completion Protocol and milestone gates

- Update backlog/config.yml DoD defaults to three enforceable conditions
- Add Task Completion Protocol section to AGENTS.md with milestone gates
- Update decision-002 with enforcement reference
- Add Regrounding interlude to SAGA.md

The practice is now codified. No task is Done without evidence.
No milestone closes without verification.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Post-Recovery: Verify Milestone 1 Gate

After all five tasks are complete, verify the Milestone 1 gate:

- [ ] `make check` exits 0
- [ ] `backlog task list --plain` shows no Done tasks with unchecked ACs or DoD
- [ ] `backlog milestone list` shows three milestones
- [ ] `git status` shows a clean working tree
- [ ] Active task list shows only open work (To Do tasks for remaining milestones)

When all five conditions are met, Milestone 1: Interchangeable Parts can be formally closed. Update SAGA.md to record the passage.
