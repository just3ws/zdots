# Issue Tracker: Backlog CLI

Issues for this repo live as markdown files in `backlog/tasks/`, managed by the `backlog` CLI.

## Creating issues

```bash
# Human operator — standard task
backlog task create "Title" --priority medium

# Agent-filed issues (use this when you need operator attention)
zdots-issue "Short description"                        # type defaults to error
zdots-issue --type request  "I need zdots to do Y"
zdots-issue --type friction "Confusing, hard to use, or unclear docs"
zdots-issue --severity high "Blocking my current task"
```

Types: `error` (default), `request`, `friction`. Severity: `critical`, `high`, `medium` (default), `low`.

`zdots-issue` auto-attaches `agent-reported` + type label and the current `ZDOTS_TRACE_ID`.

## Resuming a filed ticket

`zdots-issue` prints the exact resume command and posts a `TICKET` announcement
(with a `#<type>` tag) to the `zdots` bus channel — think of it as the
"ready to work" signal in a ticketing system, without auto-spawning anything:

```bash
zdots-ctx bus-read zdots --tag request --as mike   # see open tickets by type
ztask start Z-NNN && zclaude                        # resume the one you want
```

The bus post is best-effort (a bus outage never blocks filing) and posts as
the dedicated `zdots-issue` bus identity, not the reporting agent's own.

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
