# AGENTS.md — Core Context for AI Agents

This repository is a modular, high-performance Zsh configuration ("Zdots"). All agents must adhere to the standards and use the tools defined below. It also provides an AI-friendly Bash bridge (`~/.bashrc`) for consistency across shell environments.

---

## START HERE — Run These First

Before doing anything else, run both orientation commands. They tell you what is
actually available and running right now — no assumptions, no stale docs.

```bash
# 1. Live service status + complete usage guide (AI inference, OTel, destructive warnings)
#    Works from any bash context. Use --plain for pipe-safe, ANSI-free output.
agent-guide --plain

# 2. Environment health report — validates service contracts, checks tooling,
#    reports disk, AI model status, OTel trace state. Structured JSON for agents.
capabilities --json
```

Both commands are in `bin/` which is on `$PATH` for every shell on this machine
(added by `env.sh` via `.zshenv` — no interactive zsh required).

**When to re-run:**
- `agent-guide --plain` — before any task touching AI inference or observability
- `capabilities --json` — when debugging missing tools, broken providers, or health failures

---

## Build & Validation
- **Run All Checks:** `make check` (Primary regression suite)
- **Bootstrap:** `make bootstrap`
- **Benchmark:** `make bench`

## Agent API (Standardized Tasks)
Always prefer these `make` commands for routine operations:
- **Project Mapping:** `make map` (High-signal tree of project structure)
- **Codebase Stats:** `make stats` (Lines of code and languages via `tokei`)
- **Refactoring:** `make refactor OLD='regex' NEW='replacement'` (Safe mass-replacement via `sd`)
- **Context Packing:** `make context` (Generate `.project-context.md` for LLM via `repomix`)
- **Structural Search:** `make search QUERY='pattern'` (AST-based search via `sg`)
- **Symbol Index:** `make tags` (Generate `tags` file for lookups)

## Repository Architecture
- **Environment Variables:** MUST be defined in `.zshenv`.
- **Interactive Modules:** Isolated in `conf.d/*.zsh`.
- **Custom Functions:** Autoloaded from `functions/enabled/`.
- **Aliases:** Global and DSL-like aliases live in `conf.d/80-aliases.zsh`.
- **Startup Logic:** Use the `zdefer` helper in `conf.d/70-integrations.zsh` for lazy-loading.

## Theme & Visual Standards
- **Theme:** `ZDOTS_THEME=dracula-pro` (Sub-variants: `nord`, `dracula`).
- **Prompt:** Powerlevel10k with rounded segment separators (`\uE0B4`).
- **Styles:** Theme-specific syntax highlighting and autosuggestions in `assets/`.

## Agent Efficiency Infrastructure
- **Context:** Use `repomix` to pack the repo into high-density context.
- **Metadata:** Use `tokei` for codebase stats and `universal-ctags` for symbols.
- **Token Optimization:** **Always proxy high-output commands through `rtk`**.
- **Project State:** Refer to `backlog task list` for the current roadmap and milestones.
- **Config Parsing:** Use `dasel` or `yq` for safe structured data querying.

<!-- rtk-instructions v2 - HISTORY AWARE -->
## RTK (Rust Token Killer) - History-Aware Optimizations

**Golden Rule:** Prefix high-output commands with `rtk` to minimize token noise.

### 1. High-Volume JavaScript/TS Workflow (90% savings)
You frequently run deep verification suites. Always use these:
```bash
rtk pnpm verify:all     # Summarizes massive lint/test/typecheck logs
rtk pnpm playthrough:*  # Collapses long QA/Playwright trace logs
rtk pnpm install        # Compact dependency confirmations
rtk tsc                 # Groups TypeScript errors by file/code
```

### 2. Infrastructure & Cloud (85% savings)
Summarize noisy deployment and log events:
```bash
rtk fly deploy          # Highlights deployment events, hides progress spam
rtk fly logs            # Deduplicates log streams with hit counts
rtk docker logs         # Filters repetitive container output
```

### 3. Git & GitHub (60-80% savings)
Harden your context against massive diffs and logs:
```bash
rtk git status          # Ultra-compact status
rtk git diff            # Summarizes changes, prevents context flooding
rtk git log             # Compact commit history
rtk gh pr checks        # Clean table of CI status
```

### 4. Metadata & Analysis
```bash
rtk tokei               # Instant codebase orientation
rtk summary <cmd>       # Smart summary of any command output
rtk json <file>         # Schema-only view of large JSON files
```
<!-- /rtk-instructions -->

## Backlog.md - Task & Project State
This repository uses `backlog-md` (binary `backlog`) for task management. It is the **Source of Truth** for the project roadmap and task state.

**Agent Instructions:**
- **Discovery:** Run `backlog tasks` to see the current task list and status.
- **Context:** Use `backlog task <id>` to read deep requirements.
- **Updates:** **MUST** use the `backlog` CLI for ALL status updates and note additions.
- **Standard**: Follow the **CRITICAL** guidelines below to ensure metadata remains synchronized.


## Tooling Standards
- **History:** `atuin` (SQLite) with `history_enquire` (`he`) for maintenance.
- **Search:** `fzf` + `fzf-tab` integration.
- **File System:** `zoxide` (`z`), `eza` (aliased to `ls`), and `broot` (`br`) for weighted tree navigation.
- **AI Integration:** Use `ai-query` to pipe command output into inference from any bash context (e.g., `cat logs.txt | ai-query "summarize"`). The `ai` zsh function requires an interactive shell — do not use it from scripts or agent tools. Full guide: `docs/llama-cpp.md`.
- **Data Handling:** `jless`/`fx` for interactive JSON exploration.
- **GitHub:** Use `gh dash` for a full overview of PRs and Issues.

## Orientation Tools

| Command | Purpose | Output |
|---|---|---|
| `agent-guide --plain` | Live status of all four services + copy-paste usage for AI and OTel | Plain text, agent-safe |
| `capabilities --json` | Environment contract validation: providers, tools, disk, AI model, OTel traces | JSON |
| `capabilities` | Same as above, human-readable with colour | Terminal text |

`agent-guide` covers: AI inference endpoint, `ai-query` examples, direct HTTP patterns, OTel connection
vars, service management commands, destructive command warnings, and doc pointers — all in one output.

`capabilities --json` covers: session identity, service provider wiring, tool presence, disk space,
AI server status, OTel trace file state, and a pass/fail health verdict.

Run them together at session start:

```bash
agent-guide --plain && capabilities --json
```

---

## Local AI Runtime — llama.cpp (Central Hub)

This machine is the **primary AI inference hub** for this environment. The llama.cpp server
runs as a launchd service (auto-start on login), exposes an OpenAI-compatible HTTP API on
port 8080, and serves both chat completions and text embeddings.

### Service Management

```sh
llama-ctl status          # check launchd state + health + active model
llama-ctl status --json   # same, as JSON (pipe to jq)
llama-ctl install         # first-time: brew install + register launchd plist (auto-starts)
llama-ctl model-download  # download active profile GGUF from HuggingFace
llama-ctl start           # start server
llama-ctl stop            # stop server
llama-ctl restart         # restart server
llama-ctl logs            # tail server log (clean exit on Ctrl-C)
llama-ctl health          # quick health check (exits 0=up, 1=down)
llama-ctl health --json   # same, as JSON
llama-ctl validate        # validate etc/ai-models.yaml
```

### Inference from Agent / Script Context

> **IMPORTANT:** The `ai` zsh function requires an **interactive zsh session**.
> It is NOT available from bash subprocesses, agent sandboxes, or Claude Code's Bash tool.
> Always use `ai-query` or direct HTTP calls instead.

```sh
# Pre-flight check (always do this before inference)
llama-ctl health || { echo "Start with: llama-ctl start"; exit 1; }

# Subprocess-safe inference (works from any bash context)
ai-query "What does SIGPIPE mean?"
git diff | ai-query "Write a commit message"
cat error.log | ai-query "Find the root cause"

# Direct HTTP (no zsh environment required)
curl -sf http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"local","messages":[{"role":"user","content":"Hello"}],"stream":false}'

# Interactive shell only
history-analyze --ai         # AI-powered shell history analysis
```

### API Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /health` | Health check — exits 0 when ready |
| `GET /v1/models` | List loaded models |
| `POST /v1/chat/completions` | Chat inference (model: `"local"`) |
| `POST /v1/completions` | Text completion |
| `POST /v1/embeddings` | Text embeddings (model: `"local"`) |
| `GET /metrics` | Prometheus metrics |

**Provider:** `providers/ai/llama-cpp.zsh` — sets `ZDOTS_AI_ENDPOINT` and `ZDOTS_AI_MODEL`.
**Config:** `etc/ai-models.yaml` — GGUF filenames, HuggingFace repos, server flags, model profiles.
**Full guide:** `docs/llama-cpp.md`

**Hardware context:** M4 MBA, 16GB RAM, 256GB primary disk.
- One active GGUF at a time. ⚠️ `llama-ctl model-prune` **permanently deletes** non-active GGUFs — confirm before running.
- Default model: Qwen2.5-Coder-7B Q4_K_M (~4.7GB, `standard` profile).
- If OOM: reduce `--parallel` to 1 in `etc/ai-models.yaml`, or switch to `constrained` profile.

## Observability — OTel + LGTM Stack (Central Hub)

This machine is the **central observability hub** for this environment. Every shell command
emits an OTel span. The bare-metal `otelcol-contrib` host collector forwards telemetry to a
local LGTM stack (Grafana, Loki, Tempo, Mimir) running in Colima.

```
Shell / ai-query / local apps
        |
        v OTLP (http/protobuf, port 4318)
  otelcol-contrib (host, bare-metal)
        |
        v forward
  LGTM stack in Colima (ports 4417/4418)
        |
        v
  Grafana :3000  (http://127.0.0.1:3000, admin/admin)
  Loki           (logs)
  Tempo          (traces)
  Mimir          (metrics + RED metrics auto-derived from traces)
```

### Collector Management (bare-metal host process)

```sh
otel-collector status           # check if collector is running
otel-collector status --json    # same, as JSON (pipe to jq)
otel-collector start            # start host collector
otel-collector stop             # stop host collector
otel-collector restart          # restart (picks up config changes)
otel-collector health           # exits 0=up, 1=down
otel-collector health --json    # same, as JSON
otel-collector validate         # validate etc/otel-collector.yaml
otel-collector logs             # tail collector log (clean exit on Ctrl-C)
otel-collector install          # first-time: install otelcol-contrib binary
```

### LGTM Stack Management (Colima/Docker)

```sh
local-ci start                  # start Colima + LGTM stack
local-ci stop                   # stop LGTM stack
local-ci restart                # stop then start
local-ci status                 # check stack status
local-ci status --json          # same, as JSON (pipe to jq)
local-ci health                 # exits 0=up, 1=down
local-ci health --json          # same, as JSON
local-ci logs                   # tail LGTM stack logs (clean exit on Ctrl-C)
local-ci prune                  # dry run: show what Docker prune would free
local-ci prune -f               # DESTRUCTIVE: execute Docker prune
```

### Connecting Local Apps

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```

**Full guide:** `docs/otel-collector-guide.md` — SDK examples (Node, Python, Go, Rust), curl examples, pipeline details.

---

## Storage Hygiene — Docker / Colima / Models

Container runtime: Colima (replaces OrbStack). LGTM stack runs inside.

```sh
docker-df                    # show Docker disk consumption
docker-reclaim               # dry run: show what would be freed
docker-reclaim -f            # DESTRUCTIVE: prune containers/images/volumes/cache + fstrim
llama-ctl model-df           # show model directory size
llama-ctl model-prune        # DESTRUCTIVE: delete non-active GGUFs
```

**Full guide:** `docs/storage-hygiene.md`

**Critical:** `docker-reclaim -f` **permanently destroys** containers, images, volumes, and
build cache, then runs `fstrim` inside the Colima VM. Without `fstrim`, freed space inside
the VM does not reclaim disk on the macOS host. Always use `docker-reclaim` (dry-run first)
instead of raw `docker system prune`. ⚠️ Pass `-f` only when you have confirmed the dry-run output.

## Safety & Quality
- **Commits:** Use `git absorb` to automatically attribute fixup changes to the correct commit.
- **Guardrails:** This repository uses `pre-commit` to automate:
  - **Secret Scanning:** `gitleaks` (prevents accidental secret commits).
  - **Script Validation:** `shellcheck` (for sh/bash scripts) and `bin/check` (for the full Zsh suite).
  - **Formatting:** `shfmt` (consistent 2-space indentation for shell scripts).
  - **Hygiene:** Automatic trailing whitespace and end-of-file cleanup.

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

<!-- BACKLOG.MD GUIDELINES START -->
# Instructions for the usage of Backlog.md CLI Tool

## Backlog.md: Comprehensive Project Management Tool via CLI

### Assistant Objective

Efficiently manage all project tasks, status, and documentation using the Backlog.md CLI, ensuring all project metadata
remains fully synchronized and up-to-date.

### Core Capabilities

- ✅ **Task Management**: Create, edit, assign, prioritize, and track tasks with full metadata
- ✅ **Search**: Fuzzy search across tasks, documents, and decisions with `backlog search`
- ✅ **Acceptance Criteria**: Granular control with add/remove/check/uncheck by index
- ✅ **Definition of Done checklists**: Per-task DoD items with add/remove/check/uncheck
- ✅ **Board Visualization**: Terminal-based Kanban board (`backlog board`) and web UI (`backlog browser`)
- ✅ **Git Integration**: Automatic tracking of task states across branches
- ✅ **Dependencies**: Task relationships and subtask hierarchies
- ✅ **Documentation & Decisions**: Structured docs and architectural decision records
- ✅ **Export & Reporting**: Generate markdown reports and board snapshots
- ✅ **AI-Optimized**: `--plain` flag provides clean text output for AI processing

### Why This Matters to You (AI Agent)

1. **Comprehensive system** - Full project management capabilities through CLI
2. **The CLI is the interface** - All operations go through `backlog` commands
3. **Unified interaction model** - You can use CLI for both reading (`backlog task 1 --plain`) and writing (
   `backlog task edit 1`)
4. **Metadata stays synchronized** - The CLI handles all the complex relationships

### Key Understanding

- **Tasks** live in `backlog/tasks/` as `task-<id> - <title>.md` files
- **You interact via CLI only**: `backlog task create`, `backlog task edit`, etc.
- **Use `--plain` flag** for AI-friendly output when viewing/listing
- **Never bypass the CLI** - It handles Git, metadata, file naming, and relationships

---

# ⚠️ CRITICAL: NEVER EDIT TASK FILES DIRECTLY. Edit Only via CLI

**ALL task operations MUST use the Backlog.md CLI commands**

- ✅ **DO**: Use `backlog task edit` and other CLI commands
- ✅ **DO**: Use `backlog task create` to create new tasks
- ✅ **DO**: Use `backlog task edit <id> --check-ac <index>` to mark acceptance criteria
- ❌ **DON'T**: Edit markdown files directly
- ❌ **DON'T**: Manually change checkboxes in files
- ❌ **DON'T**: Add or modify text in task files without using CLI

**Why?** Direct file editing breaks metadata synchronization, Git tracking, and task relationships.

---

## 1. Source of Truth & File Structure

### 📖 **UNDERSTANDING** (What you'll see when reading)

- Markdown task files live under **`backlog/tasks/`** (drafts under **`backlog/drafts/`**)
- Files are named: `task-<id> - <title>.md` (e.g., `task-42 - Add GraphQL resolver.md`)
- Project documentation is in **`backlog/docs/`**
- Project decisions are in **`backlog/decisions/`**

### 🔧 **ACTING** (How to change things)

- **All task operations MUST use the Backlog.md CLI tool**
- This ensures metadata is correctly updated and the project stays in sync
- **Always use `--plain` flag** when listing or viewing tasks for AI-friendly text output

---

## 2. Common Mistakes to Avoid

### ❌ **WRONG: Direct File Editing**

```markdown
# DON'T DO THIS:

1. Open backlog/tasks/task-7 - Feature.md in editor
2. Change "- [ ]" to "- [x]" manually
3. Add notes or final summary directly to the file
4. Save the file
```

### ✅ **CORRECT: Using CLI Commands**

```bash
# DO THIS INSTEAD:
backlog task edit 7 --check-ac 1  # Mark AC #1 as complete
backlog task edit 7 --notes "Implementation complete"  # Add notes
backlog task edit 7 --final-summary "PR-style summary"  # Add final summary
backlog task edit 7 -s "In Progress" -a @agent-k  # Multiple commands: change status and assign the task when you start working on the task
```

---

## 3. Understanding Task Format (Read-Only Reference)

⚠️ **FORMAT REFERENCE ONLY** - The following sections show what you'll SEE in task files.
**Never edit these directly! Use CLI commands to make changes.**

### Task Structure You'll See

```markdown
---
id: task-42
title: Add GraphQL resolver
status: To Do
assignee: [@sara]
labels: [backend, api]
---

## Description

Brief explanation of the task purpose.

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 First criterion
- [x] #2 Second criterion (completed)
- [ ] #3 Third criterion

<!-- AC:END -->

## Definition of Done

<!-- DOD:BEGIN -->

- [ ] #1 Tests pass
- [ ] #2 Docs updated

<!-- DOD:END -->

## Implementation Plan

1. Research approach
2. Implement solution

## Implementation Notes

Progress notes captured during implementation.

## Final Summary

PR-style summary of what was implemented.
```

### How to Modify Each Section

| What You Want to Change | CLI Command to Use                                       |
|-------------------------|----------------------------------------------------------|
| Title                   | `backlog task edit 42 -t "New Title"`                    |
| Status                  | `backlog task edit 42 -s "In Progress"`                  |
| Assignee                | `backlog task edit 42 -a @sara`                          |
| Labels                  | `backlog task edit 42 -l backend,api`                    |
| Description             | `backlog task edit 42 -d "New description"`              |
| Add AC                  | `backlog task edit 42 --ac "New criterion"`              |
| Add DoD                 | `backlog task edit 42 --dod "Ship notes"`                |
| Check AC #1             | `backlog task edit 42 --check-ac 1`                      |
| Check DoD #1            | `backlog task edit 42 --check-dod 1`                     |
| Uncheck AC #2           | `backlog task edit 42 --uncheck-ac 2`                    |
| Uncheck DoD #2          | `backlog task edit 42 --uncheck-dod 2`                   |
| Remove AC #3            | `backlog task edit 42 --remove-ac 3`                     |
| Remove DoD #3           | `backlog task edit 42 --remove-dod 3`                    |
| Add Plan                | `backlog task edit 42 --plan "1. Step one\n2. Step two"` |
| Add Notes (replace)     | `backlog task edit 42 --notes "What I did"`              |
| Append Notes            | `backlog task edit 42 --append-notes "Another note"` |
| Add Final Summary       | `backlog task edit 42 --final-summary "PR-style summary"` |
| Append Final Summary    | `backlog task edit 42 --append-final-summary "Another detail"` |
| Clear Final Summary     | `backlog task edit 42 --clear-final-summary` |

---

## 4. Defining Tasks

### Creating New Tasks

**Always use CLI to create tasks:**

```bash
# Example
backlog task create "Task title" -d "Description" --ac "First criterion" --ac "Second criterion"
```

### Title (one liner)

Use a clear brief title that summarizes the task.

### Description (The "why")

Provide a concise summary of the task purpose and its goal. Explains the context without implementation details.

### Acceptance Criteria (The "what")

**Understanding the Format:**

- Acceptance criteria appear as numbered checkboxes in the markdown files
- Format: `- [ ] #1 Criterion text` (unchecked) or `- [x] #1 Criterion text` (checked)

**Managing Acceptance Criteria via CLI:**

⚠️ **IMPORTANT: How AC Commands Work**

- **Adding criteria (`--ac`)** accepts multiple flags: `--ac "First" --ac "Second"` ✅
- **Checking/unchecking/removing** accept multiple flags too: `--check-ac 1 --check-ac 2` ✅
- **Mixed operations** work in a single command: `--check-ac 1 --uncheck-ac 2 --remove-ac 3` ✅

```bash
# Examples

# Add new criteria (MULTIPLE values allowed)
backlog task edit 42 --ac "User can login" --ac "Session persists"

# Check specific criteria by index (MULTIPLE values supported)
backlog task edit 42 --check-ac 1 --check-ac 2 --check-ac 3  # Check multiple ACs
# Or check them individually if you prefer:
backlog task edit 42 --check-ac 1    # Mark #1 as complete
backlog task edit 42 --check-ac 2    # Mark #2 as complete

# Mixed operations in single command
backlog task edit 42 --check-ac 1 --uncheck-ac 2 --remove-ac 3

# ❌ STILL WRONG - These formats don't work:
# backlog task edit 42 --check-ac 1,2,3  # No comma-separated values
# backlog task edit 42 --check-ac 1-3    # No ranges
# backlog task edit 42 --check 1         # Wrong flag name

# Multiple operations of same type
backlog task edit 42 --uncheck-ac 1 --uncheck-ac 2  # Uncheck multiple ACs
backlog task edit 42 --remove-ac 2 --remove-ac 4    # Remove multiple ACs (processed high-to-low)
```

### Definition of Done checklist (per-task)

Definition of Done items are a second checklist in each task. Defaults come from `definition_of_done` in the project config file (`backlog/config.yml`, `.backlog/config.yml`, or `backlog.config.yml`) or from Web UI Settings, and can be disabled per task.

**Managing Definition of Done via CLI:**

```bash
# Add DoD items (MULTIPLE values allowed)
backlog task edit 42 --dod "Run tests" --dod "Update docs"

# Check/uncheck DoD items by index (MULTIPLE values supported)
backlog task edit 42 --check-dod 1 --check-dod 2
backlog task edit 42 --uncheck-dod 1

# Remove DoD items by index
backlog task edit 42 --remove-dod 2

# Create without defaults
backlog task create "Feature" --no-dod-defaults
```

**Key Principles for Good ACs:**

- **Outcome-Oriented:** Focus on the result, not the method.
- **Testable/Verifiable:** Each criterion should be objectively testable
- **Clear and Concise:** Unambiguous language
- **Complete:** Collectively cover the task scope
- **User-Focused:** Frame from end-user or system behavior perspective

Good Examples:

- "User can successfully log in with valid credentials"
- "System processes 1000 requests per second without errors"
- "CLI preserves literal newlines in description/plan/notes/final summary; `\\n` sequences are not auto‑converted"

Bad Example (Implementation Step):

- "Add a new function handleLogin() in auth.ts"
- "Define expected behavior and document supported input patterns"

### Task Breakdown Strategy

1. Identify foundational components first
2. Create tasks in dependency order (foundations before features)
3. Ensure each task delivers value independently
4. Avoid creating tasks that block each other

### Task Requirements

- Tasks must be **atomic** and **testable** or **verifiable**
- Each task should represent a single unit of work for one PR
- **Never** reference future tasks (only tasks with id < current task id)
- Ensure tasks are **independent** and don't depend on future work

---

## 5. Implementing Tasks

### 5.1. First step when implementing a task

The very first things you must do when you take over a task are:

* set the task in progress
* assign it to yourself

```bash
# Example
backlog task edit 42 -s "In Progress" -a @{myself}
```

### 5.2. Review Task References and Documentation

Before planning, check if the task has any attached `references` or `documentation`:
- **References**: Related code files, GitHub issues, or URLs relevant to the implementation
- **Documentation**: Design docs, API specs, or other materials for understanding context

These are visible in the task view output. Review them to understand the full context before drafting your plan.

### 5.3. Create an Implementation Plan (The "how")

Previously created tasks contain the why and the what. Once you are familiar with that part you should think about a
plan on **HOW** to tackle the task and all its acceptance criteria. This is your **Implementation Plan**.
First do a quick check to see if all the tools that you are planning to use are available in the environment you are
working in.
When you are ready, write it down in the task so that you can refer to it later.

```bash
# Example
backlog task edit 42 --plan "1. Research codebase for references\n2Research on internet for similar cases\n3. Implement\n4. Test"
```

## 5.4. Implementation

Once you have a plan, you can start implementing the task. This is where you write code, run tests, and make sure
everything works as expected. Follow the acceptance criteria one by one and MARK THEM AS COMPLETE as soon as you
finish them.

### 5.5 Implementation Notes (Progress log)

Use Implementation Notes to log progress, decisions, and blockers as you work.
Append notes progressively during implementation using `--append-notes`:

```
backlog task edit 42 --append-notes "Investigated root cause" --append-notes "Added tests for edge case"
```

```bash
# Example
backlog task edit 42 --notes "Initial implementation done; pending integration tests"
```

### 5.6 Final Summary (PR description)

When you are done implementing a task you need to prepare a PR description for it.
Because you cannot create PRs directly, write the PR as a clean summary in the Final Summary field.

**Quality bar:** Write it like a reviewer will see it. A one‑liner is rarely enough unless the change is truly trivial.
Include the key scope so someone can understand the impact without reading the whole diff.

```bash
# Example
backlog task edit 42 --final-summary "Implemented pattern X because Reason Y; updated files Z and W; added tests"
```

**IMPORTANT**: Do NOT include an Implementation Plan when creating a task. The plan is added only after you start the
implementation.

- Creation phase: provide Title, Description, Acceptance Criteria, and optionally labels/priority/assignee.
- When you begin work, switch to edit, set the task in progress and assign to yourself
  `backlog task edit <id> -s "In Progress" -a "..."`.
- Think about how you would solve the task and add the plan: `backlog task edit <id> --plan "..."`.
- After updating the plan, share it with the user and ask for confirmation. Do not begin coding until the user approves the plan or explicitly tells you to skip the review.
- Append Implementation Notes during implementation using `--append-notes` as progress is made.
- Add Final Summary only after completing the work: `backlog task edit <id> --final-summary "..."` (replace) or append using `--append-final-summary`.

## Phase discipline: What goes where

- Creation: Title, Description, Acceptance Criteria, labels/priority/assignee.
- Implementation: Implementation Plan (after moving to In Progress and assigning to yourself) + Implementation Notes (progress log, appended as you work).
- Wrap-up: Final Summary (PR description), verify AC and Definition of Done checks.

**IMPORTANT**: Only implement what's in the Acceptance Criteria. If you need to do more, either:

1. Update the AC first: `backlog task edit 42 --ac "New requirement"`
2. Or create a new follow up task: `backlog task create "Additional feature"`

---

## 6. Typical Workflow

```bash
# 1. Identify work
backlog task list -s "To Do" --plain

# 2. Read task details
backlog task 42 --plain

# 3. Start work: assign yourself & change status
backlog task edit 42 -s "In Progress" -a @myself

# 4. Add implementation plan
backlog task edit 42 --plan "1. Analyze\n2. Refactor\n3. Test"

# 5. Share the plan with the user and wait for approval (do not write code yet)

# 6. Work on the task (write code, test, etc.)

# 7. Mark acceptance criteria as complete (supports multiple in one command)
backlog task edit 42 --check-ac 1 --check-ac 2 --check-ac 3  # Check all at once
# Or check them individually if preferred:
# backlog task edit 42 --check-ac 1
# backlog task edit 42 --check-ac 2
# backlog task edit 42 --check-ac 3

# 8. Add Final Summary (PR Description)
backlog task edit 42 --final-summary "Refactored using strategy pattern, updated tests"

# 9. Mark task as done
backlog task edit 42 -s Done
```

---

## 7. Definition of Done (DoD)

A task is **Done** only when **ALL** of the following are complete:

### ✅ Via CLI Commands:

1. **All acceptance criteria checked**: Use `backlog task edit <id> --check-ac <index>` for each
2. **All Definition of Done items checked**: Use `backlog task edit <id> --check-dod <index>` for each
3. **Final Summary added**: Use `backlog task edit <id> --final-summary "..."`
4. **Status set to Done**: Use `backlog task edit <id> -s Done`

### ✅ Via Code/Testing:

5. **Tests pass**: Run test suite and linting
6. **Documentation updated**: Update relevant docs if needed
7. **Code reviewed**: Self-review your changes
8. **No regressions**: Performance, security checks pass

⚠️ **NEVER mark a task as Done without completing ALL items above**

---

## 8. Finding Tasks and Content with Search

When users ask you to find tasks related to a topic, use the `backlog search` command with `--plain` flag:

```bash
# Search for tasks about authentication
backlog search "auth" --plain

# Search only in tasks (not docs/decisions)
backlog search "login" --type task --plain

# Search with filters
backlog search "api" --status "In Progress" --plain
backlog search "bug" --priority high --plain
```

**Key points:**
- Uses fuzzy matching - finds "authentication" when searching "auth"
- Searches task titles, descriptions, and content
- Also searches documents and decisions unless filtered with `--type task`
- Always use `--plain` flag for AI-readable output

---

## 9. Quick Reference: DO vs DON'T

### Viewing and Finding Tasks

| Task         | ✅ DO                        | ❌ DON'T                         |
|--------------|-----------------------------|---------------------------------|
| View task    | `backlog task 42 --plain`   | Open and read .md file directly |
| List tasks   | `backlog task list --plain` | Browse backlog/tasks folder     |
| Check status | `backlog task 42 --plain`   | Look at file content            |
| Find by topic| `backlog search "auth" --plain` | Manually grep through files |

### Modifying Tasks

| Task          | ✅ DO                                 | ❌ DON'T                           |
|---------------|--------------------------------------|-----------------------------------|
| Check AC      | `backlog task edit 42 --check-ac 1`  | Change `- [ ]` to `- [x]` in file |
| Add notes     | `backlog task edit 42 --notes "..."` | Type notes into .md file          |
| Add final summary | `backlog task edit 42 --final-summary "..."` | Type summary into .md file |
| Change status | `backlog task edit 42 -s Done`       | Edit status in frontmatter        |
| Add AC        | `backlog task edit 42 --ac "New"`    | Add `- [ ] New` to file           |

---

## 10. Complete CLI Command Reference

### Task Creation

| Action           | Command                                                                             |
|------------------|-------------------------------------------------------------------------------------|
| Create task      | `backlog task create "Title"`                                                       |
| With description | `backlog task create "Title" -d "Description"`                                      |
| With AC          | `backlog task create "Title" --ac "Criterion 1" --ac "Criterion 2"`                 |
| With final summary | `backlog task create "Title" --final-summary "PR-style summary"`                 |
| With references  | `backlog task create "Title" --ref src/api.ts --ref https://github.com/issue/123`   |
| With documentation | `backlog task create "Title" --doc https://design-docs.example.com`               |
| With all options | `backlog task create "Title" -d "Desc" -a @sara -s "To Do" -l auth --priority high --ref src/api.ts --doc docs/spec.md` |
| Create draft     | `backlog task create "Title" --draft`                                               |
| Create subtask   | `backlog task create "Title" -p 42`                                                 |

### Task Modification

| Action           | Command                                     |
|------------------|---------------------------------------------|
| Edit title       | `backlog task edit 42 -t "New Title"`       |
| Edit description | `backlog task edit 42 -d "New description"` |
| Change status    | `backlog task edit 42 -s "In Progress"`     |
| Assign           | `backlog task edit 42 -a @sara`             |
| Add labels       | `backlog task edit 42 -l backend,api`       |
| Set priority     | `backlog task edit 42 --priority high`      |

### Acceptance Criteria Management

| Action              | Command                                                                     |
|---------------------|-----------------------------------------------------------------------------|
| Add AC              | `backlog task edit 42 --ac "New criterion" --ac "Another"`                  |
| Remove AC #2        | `backlog task edit 42 --remove-ac 2`                                        |
| Remove multiple ACs | `backlog task edit 42 --remove-ac 2 --remove-ac 4`                          |
| Check AC #1         | `backlog task edit 42 --check-ac 1`                                         |
| Check multiple ACs  | `backlog task edit 42 --check-ac 1 --check-ac 3`                            |
| Uncheck AC #3       | `backlog task edit 42 --uncheck-ac 3`                                       |
| Mixed operations    | `backlog task edit 42 --check-ac 1 --uncheck-ac 2 --remove-ac 3 --ac "New"` |

### Task Content

| Action           | Command                                                  |
|------------------|----------------------------------------------------------|
| Add plan         | `backlog task edit 42 --plan "1. Step one\n2. Step two"` |
| Add notes        | `backlog task edit 42 --notes "Implementation details"`  |
| Add final summary | `backlog task edit 42 --final-summary "PR-style summary"` |
| Append final summary | `backlog task edit 42 --append-final-summary "More details"` |
| Clear final summary | `backlog task edit 42 --clear-final-summary` |
| Add dependencies | `backlog task edit 42 --dep task-1 --dep task-2`         |
| Add references   | `backlog task edit 42 --ref src/api.ts --ref https://github.com/issue/123` |
| Add documentation | `backlog task edit 42 --doc https://design-docs.example.com --doc docs/spec.md` |

### Multi‑line Input (Description/Plan/Notes/Final Summary)

The CLI preserves input literally. Shells do not convert `\n` inside normal quotes. Use one of the following to insert real newlines:

- Bash/Zsh (ANSI‑C quoting):
  - Description: `backlog task edit 42 --desc $'Line1\nLine2\n\nFinal'`
  - Plan: `backlog task edit 42 --plan $'1. A\n2. B'`
  - Notes: `backlog task edit 42 --notes $'Done A\nDoing B'`
  - Append notes: `backlog task edit 42 --append-notes $'Progress update line 1\nLine 2'`
  - Final summary: `backlog task edit 42 --final-summary $'Shipped A\nAdded B'`
  - Append final summary: `backlog task edit 42 --append-final-summary $'Added X\nAdded Y'`
- POSIX portable (printf):
  - `backlog task edit 42 --notes "$(printf 'Line1\nLine2')"`
- PowerShell (backtick n):
  - `backlog task edit 42 --notes "Line1`nLine2"`

Do not expect `"...\n..."` to become a newline. That passes the literal backslash + n to the CLI by design.

Descriptions support literal newlines; shell examples may show escaped `\\n`, but enter a single `\n` to create a newline.

### Implementation Notes Formatting

- Keep implementation notes concise and time-ordered; focus on progress, decisions, and blockers.
- Use short paragraphs or bullet lists instead of a single long line.
- Use Markdown bullets (`-` for unordered, `1.` for ordered) for readability.
- When using CLI flags like `--append-notes`, remember to include explicit
  newlines. Example:

  ```bash
  backlog task edit 42 --append-notes $'- Added new API endpoint\n- Updated tests\n- TODO: monitor staging deploy'
  ```

### Final Summary Formatting

- Treat the Final Summary as a PR description: lead with the outcome, then add key changes and tests.
- Keep it clean and structured so it can be pasted directly into GitHub.
- Prefer short paragraphs or bullet lists and avoid raw progress logs.
- Aim to cover: **what changed**, **why**, **user impact**, **tests run**, and **risks/follow‑ups** when relevant.
- Avoid single‑line summaries unless the change is truly tiny.

**Example (good, not rigid):**
```
Added Final Summary support across CLI/MCP/Web/TUI to separate PR summaries from progress notes.

Changes:
- Added `finalSummary` to task types and markdown section parsing/serialization (ordered after notes).
- CLI/MCP/Web/TUI now render and edit Final Summary; plain output includes it.

Tests:
- bun test src/test/final-summary.test.ts
- bun test src/test/cli-final-summary.test.ts
```

### Task Operations

| Action             | Command                                      |
|--------------------|----------------------------------------------|
| View task          | `backlog task 42 --plain`                    |
| List tasks         | `backlog task list --plain`                  |
| Search tasks       | `backlog search "topic" --plain`              |
| Search with filter | `backlog search "api" --status "To Do" --plain` |
| Filter by status   | `backlog task list -s "In Progress" --plain` |
| Filter by assignee | `backlog task list -a @sara --plain`         |
| Archive task       | `backlog task archive 42`                    |
| Demote to draft    | `backlog task demote 42`                     |

---

## Common Issues

| Problem              | Solution                                                           |
|----------------------|--------------------------------------------------------------------|
| Task not found       | Check task ID with `backlog task list --plain`                     |
| AC won't check       | Use correct index: `backlog task 42 --plain` to see AC numbers     |
| Changes not saving   | Ensure you're using CLI, not editing files                         |
| Metadata out of sync | Re-edit via CLI to fix: `backlog task edit 42 -s <current-status>` |

---

## Remember: The Golden Rule

**🎯 If you want to change ANYTHING in a task, use the `backlog task edit` command.**
**📖 Use CLI to read tasks, exceptionally READ task files directly, never WRITE to them.**

Full help available: `backlog --help`

<!-- BACKLOG.MD GUIDELINES END -->
