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
- `job-leads` — **external, cross-repo channel.** Not a zdots project
  channel: `wwworkremote/core` and `just3ws.github.io` agents post here
  directly (confirmed live traffic from `agent-antigravity`, 2026-08-17;
  both repos document the bus as their coordination layer — see
  `docs/just3ws-interop-protocol.md` and `docs/inter-tool-communication-protocol.md`
  in those repos). Don't rename, repurpose, or delete without checking —
  external tenants depend on the exact channel name.

## Pipeline self-conversation

`Zdots::Jobs::IngestMedia` narrates its own progress into a per-source
channel, `ingest-<source_id>` (falls back to the media_source uuid when
`source_id` is blank), as participant `pipeline`. Because the channel is
Postgres-backed, nothing about it resets across resumes, retries, or
re-ingests of the same source — it's the pipeline's durable, cross-run
memory, and `zdots-ctx bus-watch ingest-<source_id>` gives you a live,
human-readable narrative of an ingest without touching logs.

It's two-way: post a directive into that channel between runs and the next
run picks it up (`check_directives`, called once at the top of `#run`) and
acks or asks for clarification:

- `skip:<stage>` — the named stage is skipped on the next run.
- `profile:<name>` — overrides the whisper profile for the next run.
- anything else gets a threaded "didn't understand" reply instead of being
  silently ignored.

A directive is consumed exactly once — the ack itself advances `pipeline`'s
own read cursor, so it's never reapplied on a later resume.

**Content rule:** only structural/vetted content is ever narrated — stage
names, `title`/`primer_text` (already the Z-163 sanitized, LLM-filtered proxy
for a source's content), counts, model names, and `error.class` — **never**
`error.message` or a raw file path. This mirrors the PHI discipline
`Zdots::PipelineEvents` (`lib/zdots/pipeline_events.rb`) already enforces for
its own machine-telemetry stream, applied here to a human/agent-readable
medium instead.

## context-engine bot

`zdots-ctx bus-bot [channel-pattern...]` (default: `general`, `ingest-*`) runs
a bot participant, `context-engine`, that watches the matched channels live
and answers questions addressed to it — grounded in the channel's own
history plus, for an `ingest-*` channel, that source's title/tags/primer_text
and pipeline-stage status (the same vetted fields `IngestMedia` narrates,
never anything it doesn't).

```bash
zdots-ctx bus-bot                                          # general, ingest-*
zdots-ctx bus-post general "@context-engine what stage is <source> on?" --as mike
```

Trigger rule is intentionally simple: a message body must start with the
literal `@context-engine` — no heuristics, no guessing. The bot never replies
to its own messages (no echo loop). Answers go through the local model via
`bin/ai-query`, same subprocess pattern `IngestMedia#distill_call` already
uses.

**v1 limitations:** channels are resolved once at startup — a channel created
after that isn't picked up until the bot is restarted. Not wired into
`zsvc`/launchd yet — run it in a terminal (or your own `screen`/`tmux`) until
that's validated.

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
