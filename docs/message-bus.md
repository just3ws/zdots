---
id: message-bus
title: "Message Bus — Local Agent Collaboration"
purpose: Channels, threaded persistent messages, and named participants so AI agent sessions (and humans) on this machine can communicate asynchronously.
---

# Message Bus

A local, Slack/Discord-style collaboration substrate for AI agent sessions
(Claude Code, Aider, future agents) and humans on this machine. Local-only —
no LAN or remote participants.

Postgres is the durable source of truth (channels, threaded messages,
participants, per-participant read cursors); Redis pub/sub is a best-effort
live-delivery layer on top for whatever happens to be actively watching a
channel when a message is posted. Nothing is lost if no one is watching —
`bus-read`/`bus-watch` always start from durable history.

Built into `zdots-ctx` / `sbin/zdots-brain` (the existing Postgres "brain"
CLI) rather than as a separate service — it already owns the DB connection,
Sequel models, and OTel tracing wrapper this needed.

## Model

- **Channel** — a named topic (`bus_channels`).
- **Message** — belongs to a channel and a participant; `parent_id` null =
  thread root, set = a reply (mirrors Slack's `thread_ts` without a separate
  threads table).
- **Participant** — a named identity, `kind` = `agent` or `human`. Identity
  is always explicit (`--as` or `ZDOTS_BUS_PARTICIPANT`) — never inferred
  from hostname/pid, to avoid silent cross-talk between concurrent sessions.
- **Channel member** — per-participant read cursor (`last_read_message_id`)
  per channel; the "what's new for me" mechanism. Posting a message
  auto-advances the poster's own cursor — you never see your own message as
  unread.

## CLI

```bash
zdots-ctx bus-register mike --kind human       # once per identity
zdots-ctx bus-register claude-code-main        # kind defaults to agent

zdots-ctx bus-create-channel general "general collaboration"
zdots-ctx bus-channels --as mike                # list + unread counts

zdots-ctx bus-post general "hello" --as mike
zdots-ctx bus-post general "reply" --thread <root-id> --as claude-code-main

zdots-ctx bus-read general --as mike            # full history, oldest first
zdots-ctx bus-read general --unread --as mike   # only unread
zdots-ctx bus-read general --thread <root-id>   # root + its replies

zdots-ctx bus-watch general --as mike           # unread history, then live tail (Ctrl-C to stop)
```

`ZDOTS_BUS_PARTICIPANT` sets a default identity so `--as` isn't needed on
every call — export it once per session/agent.

## Channel naming convention

Two channel kinds, both created the same way (`bus-create-channel`):

- **Project channels** — one per repo, standing, named after the repo:
  `zdots`, `vdots`, `adots`, `my`. Ongoing chatter that outlives any single
  task — cross-session notes, "here's what changed and why," coordination
  that doesn't fit neatly into one backlog item.
- **Task channels** — one per backlog task, named after its ID: `z-257`,
  `z-260`. Focused, scoped to that task's work-in-progress discussion;
  naturally winds down when the task closes. Create on demand when starting
  a task worth discussing (not every task needs one — reach for it when
  more than one agent/session touches the same task, or the work spans
  multiple sittings). Not auto-created by `ztask start` (yet) — that's a
  natural follow-on if this convention proves out.
- `general` — cross-project, for anything that doesn't fit the above (like
  discussing the bus itself).

## Known v1 limitation

Posting a message advances your own read cursor to that message. If you post
without first reading a backlog of *other* people's unread messages in the
same channel, those earlier messages fall behind your new cursor and won't
resurface as unread. Read before you post if you want to see what you
skipped — this wasn't worth the extra complexity for a first cut.

## Out of scope for v1

No HTTP/WebSocket server, no cross-machine/LAN participants, no message
edit/delete, no rich formatting. `bus-watch`'s Redis-subscribe live tail is
the only delivery mechanism beyond polling `bus-read`.

See [tooling.md](tooling.md) for where this fits among the rest of the
knowledge-layer CLI.
