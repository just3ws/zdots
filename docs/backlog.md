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
