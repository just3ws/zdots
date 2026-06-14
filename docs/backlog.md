# Backlog.md Guide

This project uses `backlog-md` for task management. It is the Source of Truth for the roadmap and task state.

## 1. Core Commands

| Action | Command |
|---|---|
| Discovery | `backlog tasks` |
| View Task | `backlog task <id>` |
| Edit Task | `backlog task edit <id>` |
| Search | `backlog search "topic"` |

Always use the `--plain` flag for AI-friendly text output.

## 1.1 Repo Configuration

Backlog is configured for local, agent-safe operation in this repo:

| Setting | Value | Reason |
|---|---|---|
| `auto_commit` | `true` | Task metadata changes stay tracked and auditable |
| `remote_operations` | `false` | Routine task edits never fetch/prune remotes from agent sessions |
| `auto_open_browser` | `false` | CLI workflows do not open GUI browser windows |
| `bypass_git_hooks` | `false` | Task commits keep the repo's normal safety checks |
| `check_active_branches` | `true` | Local branch awareness remains enabled |
| `labels` | `agent-reported`, `bug`, `question`, `request`, `needs-info`, `agent-ready` | Matches `zdots-issue` and agent triage vocabulary |

Use `backlog config list` to verify these values.

## 2. Task Completion Protocol

No task is **Done** until:

1. **Every acceptance criterion is checked.** Reference evidence (output, file path).
2. **`make check` passes.** Output captured in commit or notes.
3. **All Definition of Done items are checked.**
4. **A Final Summary is written.** Describes what, why, and how.
5. **All related changes are committed.**

## 3. Milestones

Tasks are organized into milestones. No milestone closes until all assigned tasks are Done and `SAGA.md` is updated.

## 4. Critical Rule: Never Edit Task Files Directly

**All task operations MUST use the Backlog.md CLI.**
Direct file editing breaks metadata synchronization and Git tracking.
Use `backlog task edit <id> --check-ac <index>` instead of manually changing checkboxes.

`ztask` follows the same rule: status changes go through
`backlog task edit <id> --status ...`, while the active-task marker remains local
state under `~/.local/state/zsh/active_task`.

Architecture and documentation audit work should reference
`docs/architecture-diagram-audit-plan.md` so the plan remains visible to future
agents and does not live only in conversation history.

## 5. Dependency Graph & Leverage Waves

Execution priority is driven by **dependency leverage**, not task count or
feature visibility. Make the right next task the *obvious* one by encoding the
graph, then letting the tool surface it:

1. **Encode edges natively.** `backlog task edit <id> --depends-on <ids>`. A task
   depends on the foundation that must land first. Never track dependencies in
   prose or a side file.
2. **Let the tool compute order.** `backlog sequence list --plain` topologically
   sequences the open backlog from those edges (and proves it is a DAG — it errors
   on a cycle). This is the **live source of truth** for what *can* run now.
3. **Overlay leverage with labels.** `wave1`..`wave4` labels rank *what should run
   first* within the unblocked set (highest downstream unlock per unit effort).
   `set:<feature>` labels group feature sets. Query: `backlog task list --labels wave1`.
4. **Rule:** pick the **lowest-wave** task among the currently-unblocked
   (Sequence 1) tasks. Do not start a later wave while a foundation it depends on
   is open.

The rationale snapshot — graph, leverage ranking, divergence flags — lives in the
Backlog.md doc **`analysis/dependency-graph` (doc-003)**: `backlog doc view doc-003`.
When task state changes, trust `backlog sequence`, then refresh that doc.

Favor **convergence over proliferation**: before implementing, verify no
equivalent solution exists and extend the existing abstraction rather than adding
a competing one. If you detect architectural divergence, stop and record it on the
board (a task comment) instead of building the duplicate.

## 6. "Backlog.md" is the tool, not a file

"Backlog.md" refers to the **Backlog.md CLI/MCP** (github.com/MrLesk/Backlog.md),
driven via `backlog`. It is **not** a literal file to create.

- Never create a `Backlog.md` or `backlog.md` file as a planning/roadmap surface.
  Tasks live in `backlog/tasks/`, docs in `backlog/docs/`, decisions in
  `backlog/decisions/` — all managed through the tool.
- `docs/backlog.md` (this guide) is the **only** sanctioned literal file, and it
  documents the tool; it is not task state.
- If you find a stray literal `Backlog.md`/`backlog.md` planning artifact, treat it
  as a legacy AI mistake: migrate any real ideas onto the board via `task create`,
  then remove the file.
