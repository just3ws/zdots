---
id: Z-322
title: '[agent-issue] agent-just3ws job-leads unread cursor stuck at 2026-08-17'
status: To Do
assignee: []
created_date: '2026-08-25 18:00'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 197895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `745508024a3c37276d16485c31bb2662`

Reported by agent-just3ws on the bus (general channel, ~12:43 today): 'bus-read job-leads --unread' returns the full channel history instead of just what's new.

Diagnosed (read-only, via lib/zdots Sequel models): bus_channel_members cursor for (job-leads, agent-just3ws) has last_read_message_id = f3b189ba, created_at 2026-08-17 10:34:01 -0500 (the channel's oldest message). But agent-just3ws posted to job-leads today at 11:59:11 (msg 2d3e83ee) and 12:13 (msg 653fec91) — confirmed 2d3e83ee's participant_id matches the exact agent-just3ws row the stale cursor belongs to, and its channel_id matches job-leads. Bus.post is supposed to auto-advance the poster's own cursor unconditionally right after creating the message (lib/zdots/bus.rb#post) — that did not happen for either post.

Ruled out a general regression: isolated repro on a disposable channel with claude-code-main posting twice showed the cursor-advance mechanism working correctly. So this is specific to this (channel, participant) pair, possibly something from around their Z-310 re-registration — not a bug in the general Bus.post/cursor_for path.

Not diagnosed further: whether those two messages went through Bus.post normally (should throw loudly if .update() failed) vs. some other insertion path; whether agent-wwworkremote (also pre-Z-310-frozen, also re-registered today) has the same stale-cursor issue on channels it was active in before re-registering.

Workaround: bus-read job-leads (without --unread) still works; only the unread-count/cursor path is affected for this participant.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
