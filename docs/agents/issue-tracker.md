# Issue Tracker: Backlog CLI

Issues for this repo live as markdown files in `backlog/tasks/`, managed by the `backlog` CLI.

## Creating issues

```bash
# Human operator — standard task
backlog task create "Title" --priority medium

# Agent-filed issues (use this when you need operator attention)
zdots-issue "Short description"                        # bug
zdots-issue --type question "Does zdots support X?"
zdots-issue --type request  "I need zdots to do Y"
zdots-issue --high          "Blocking my current task"
```

`zdots-issue` auto-attaches `agent-reported` + type label and the current `ZDOTS_TRACE_ID`.

## Fetching a ticket

```bash
backlog task view Z-042
# or read the file directly:
cat backlog/tasks/z-042\ -\ *.md
```

## Updating a ticket

```bash
backlog task edit Z-042 --status "In Progress"
backlog task edit Z-042 --priority high
```

## File structure

```
backlog/tasks/z-NNN - slug.md      ← active tasks
backlog/completed/z-NNN - slug.md  ← completed tasks
backlog/docs/                      ← project documentation
```

Each task file has YAML-like frontmatter with `status`, `priority`, `labels`, and optional `Acceptance Criteria` and `Definition of Done` sections.

## Task IDs

IDs follow the pattern `Z-NNN` (e.g. `Z-092`). Always reference by ID when linking tasks.
