---
id: Z-297
title: >-
  [agent-issue] mcp__ctx__ctx_add_lesson (zdots-ctx add-lesson path) shells out
  unsafely: content containing an apos
status: Done
assignee: []
created_date: '2026-08-07 20:11'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 172895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `6c2b280e6d47707657cc35934e3c6cc6`

mcp__ctx__ctx_add_lesson (zdots-ctx add-lesson path) shells out unsafely: content containing an apostrophe or parentheses breaks with bash syntax errors (e.g. "it's", "launcher.rb: `clustered? = ...`"). Had to strip all contractions/backticks/parens from lesson content to get it to save. Looks like content is interpolated into a shell command rather than passed as an argument/stdin.

---

**ESCALATED 2026-08-22 — low/friction was wrong. This is command execution.**

The original report saw only the *visible* half (bash syntax errors, worked
around by stripping contractions). Root-caused and reproduced 2026-08-22:
`bin/ctx-mcp:49` escapes with `arg.gsub("'", "'\\''")`, but in a Ruby gsub
*string* replacement `\'` is the post-match backreference, so the intended POSIX
escape expands to `'` + everything-after-the-match + `'`. Every apostrophe
therefore closes the single-quoted string, and content after it is parsed by
bash as source rather than data.

Marker-file PoC (verbatim escaping logic, scratch dir):

    "subshell $(touch MARKER)"       -> inert, no execution
    "it's a $(touch MARKER) day"     -> MARKER CREATED — subshell EXECUTED
    "the other's domain (like this)" -> bash: syntax error near unexpected token `('

The syntax error this ticket originally described and arbitrary command
execution are the same defect; which one fires depends only on whether a
metacharacter follows an apostrophe. Affects every `run_ctx` caller — reads
included (`ctx_query`, `ctx_hydrate`, `ctx_semantic_search`), and the silent
non-error case corrupts stored Lesson text at exit 0.

Full analysis, threat model and suggested fix (argv-form `Open3.capture3`,
no shell): **Z-309**. Independently corroborated by the wwworkremote peer
session, which hit both bash errors on live writes.

**Filed low on 2026-08-07 and still open 2026-08-22** — 15 days of agents
routing scraped, transcribed and peer-authored text through this path.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed 2026-08-22 in commit 5840de41. Both ctx-mcp and o2-mcp now pass arguments
as positional parameters ("$@") and exec the target directly; nothing derived
from tool input is parsed by bash as source. The shell remains only to source
env.sh.

**Scope was wider than reported.** The audit found the identical idiom in
`bin/o2-mcp:112`, which neither ticket named — same hand-rolled gsub escape,
same `bash -c` interpolation. Both fixed together. A third site,
`lib/zdots/ai/publisher.rb:29`, uses the same `\'` backreference trap but feeds
argv-form `Open3.capture3` with no shell, so it mangles a path inside ffmpeg's
filter parser rather than executing anything — real but low, left open.

**Verified by reverting** (old logic: marker file created, all payloads
mangled), then reapplying (all intact, no marker), then exercising both servers
over real JSON-RPC.

**Correction to the reported blast radius.** A peer session asserted that the
bulk just3ws transcript sync had silently mangled all 207 lessons on every run
and that the knowledge base should be treated as untrustworthy. Measured before
repeating it: of 325 lessons, **198 contain apostrophes and are intact**, and
only 2 show a repeated-phrase signature (one of which reads as genuine repeated
speech). The bulk sync does not route through ctx-mcp — the defect was in the
agent-facing MCP servers, not the `zdots-ctx add-lesson` CLI path. No re-sync is
needed for corruption reasons.
<!-- SECTION:NOTES:END -->
