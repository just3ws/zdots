---
id: Z-318
title: >-
  [agent-issue] zdots-patch-export still defaults to ~/Desktop/outbox — moved to
  ~/ai/outbox; mkdir -p silently recr
status: To Do
assignee: []
created_date: '2026-08-24 16:04'
updated_date: '2026-08-24 16:04'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 193895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

zdots-patch-export still defaults to ~/Desktop/outbox — moved to ~/ai/outbox; mkdir -p silently recreates the dead path

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Operator moved the AI drop points on 2026-08-24:

    ~/Desktop/inbox  -> ~/ai/inbox
    ~/Desktop/outbox -> ~/ai/outbox

Both old paths are gone. (Unrelated leftovers remain at `~/inbox` and
`~/outbox` with one stale item each — those are NOT the AI inbox/outbox.)

**Why this is worse than a stale doc.** `bin/zdots-patch-export:94` reads

    OUTBOX="${ZDOTS_PATCH_OUTBOX:-${HOME}/Desktop/outbox}"

and line 217 does `mkdir -p "$OUTBOX"`. So the default does not fail loudly —
it **recreates the abandoned directory and writes patches into it**. A
cross-machine patch transfer would appear to succeed while depositing files
somewhere nobody looks any more.

Filed rather than patched: changing a default output path in `bin/` is a
behaviour change on a shared seam, and the binary and its man page have to move
together with the agent-facing docs that describe its output. Five files, one
coherent change:

| File | Line(s) |
|---|---|
| `bin/zdots-patch-export` | 2, 7, 84, 94, 108, 131 |
| `man/man1/zdots-patch-export.1` | 19, 164, 167 |
| `.claude/commands/zdots-patch-cycle.md` | 119, 161 |
| `.claude/commands/platform-integrate.md` | 76 |
| `.claude/commands/zdots.md` | 35 |

Suggested: default to `${HOME}/ai/outbox`, keep `ZDOTS_PATCH_OUTBOX` as the
override, and consider warning rather than silently `mkdir -p`ing when the
target does not already exist — that is what would have surfaced this move on
its own.

Deliberately not touched in the same pass: dated files under
`~/.config/adots/handoffs/` also name the old paths, but they are historical
logs and rewriting them would falsify the record.
<!-- SECTION:NOTES:END -->
