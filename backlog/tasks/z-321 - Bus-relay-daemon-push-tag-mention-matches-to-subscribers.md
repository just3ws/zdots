---
id: Z-321
title: 'Bus relay daemon: push #tag/@mention matches to subscribers'
status: To Do
assignee: []
created_date: '2026-08-25 17:37'
labels:
  - feature
  - bus
  - agent-collaboration
dependencies: []
ordinal: 196895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Follow-on to the bus channel-protocol/tags/mentions/type feature (2026-08-25). #tag and @mention are currently filter-only (bus-read/bus-watch --tag/--mention) — nothing pushes a match to anyone; a session only sees it if it actively polls or watches. Mike has stated a preference for live/real-time updates when feasible, which raises this above 'someday.'

Scope: generalize the existing bus-bot pattern (zdots-ctx bus-bot, currently only the @context-engine trigger) into a persistent relay: watch all channels via the existing Redis pub/sub live-delivery path, and when a new message's metadata->mentions or metadata->tags matches something a participant subscribed to, notify them — cross-session SendMessage for a live Claude Code session (visible via ListAgents), an OS notification (osascript/terminal-notifier) for a human otherwise.

Needs: a subscriptions mechanism (participant -> tags/mentions of interest; simplest form is 'notify me on any @mention of my own name', which needs no new table), and zsvc/launchd wiring so it's not a foreground-only process (bus-bot's existing v1 limitation, docs/message-bus.md). Not a CLI flag — this is a small persistent service.

See docs/message-bus.md 'Channel protocol, tags, mentions, message kind' section, 'Not built (yet)' paragraph.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
