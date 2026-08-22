---
id: Z-309
title: >-
  [agent-issue] ctx-mcp run_ctx escaping corrupts apostrophes via Ruby gsub
  backreference — silent data mangling in
status: Done
assignee: []
created_date: '2026-08-22 15:09'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 184895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `446f549869793a94583c5f920f60268f`

ctx-mcp run_ctx escaping corrupts apostrophes via Ruby gsub backreference — silent data mangling in ctx_add_lesson (not injection)

**Duplicate-of / supersedes:** Z-297 (same defect, filed 2026-08-07 as
friction/low; now escalated to high and cross-linked here). Resolve together.

**Reported by** the wwworkremote peer session as "ctx_add_lesson interpolates
content into `bash -c` unquoted — parentheses and backticks reach the shell."
Verified: **that diagnosis is wrong, but there is a real bug underneath it.**

`bin/ctx-mcp:49` builds the command as:

    escaped_args = args.map { |arg| "'" + arg.to_s.gsub("'", "'\\''") + "'" }.join(" ")

**CORRECTION 2026-08-22 — this IS remote-ish command injection. Severity raised
to high.** My first analysis tested each metacharacter class in isolation and
concluded "corruption only". The wwworkremote peer session pushed back with real
bash errors from its own failed writes and was right. The reachable case is an
apostrophe FOLLOWED by a metacharacter: the doubled apostrophe closes the
single-quoted string, so everything after it is parsed by bash as source, not data.

Verified with the verbatim escaping logic (marker-file PoC, scratch dir):

    "subshell $(touch MARKER)"        -> rc=0, no execution   (isolated metachar: inert)
    "it's a $(touch MARKER) day"      -> rc=0, MARKER CREATED (subshell EXECUTED)
    "the other's domain (like this)"  -> rc=2, bash: syntax error near unexpected token `('

The second line is arbitrary command execution from ordinary English prose —
an apostrophe plus a `$(...)` anywhere later in the body. The third reproduces
the peer's observed `syntax error`, and their other error, `**just3ws.localhost:
command not found`, is bash executing a content fragment as a command word.

Corruption and execution are the same defect at different severities; which one
you get depends only on whether a metacharacter happens to follow an apostrophe.
Prose reliably contains apostrophes.

**Threat model:** any content routed into ctx_* by an agent — including text
originating from a scraped web page, a transcript, a peer agent's message, or a
document being ingested — becomes shell input running as the user. This is on a
PHI-adjacent machine.

**Original (incorrect) analysis retained below for the record.**

**Not injection.** Ran every metacharacter class through the verbatim escaping
logic. Parens, backticks, `$(...)` and `;` all arrive as literal text; a
`$(touch PWNED)` payload created no file. Shell-metacharacter defence holds.

    rc=0 intact=true  <<parens (like this) and backticks `id`>>
    rc=0 intact=true  <<subshell $(touch .../PWNED)>>
    rc=0 intact=true  <<semicolon ; touch .../PWNED2>>
    rc=0 intact=FALSE <<apostrophe itsfines fine>>   <-- input was "apostrophe it's fine"

**The actual defect: apostrophes silently corrupt the content.** In a Ruby
gsub *string* replacement, `\'` is the special backreference for "everything
after the match" (Perl's `$'`). The intended POSIX escape `'\''` is therefore
parsed as `'` + post-match + `'`, so `it's fine` expands to `it's fine's fine`
and reaches the CLI as `its fines fine`.

Impact (understated in the original analysis — see correction above): any Lesson, context string,
or tag containing an apostrophe — i.e. most English prose — is stored mangled,
with exit code 0 and a "✅ Lesson saved." confirmation. Silent corruption, no
error surface. Affects every `run_ctx` caller, not just `ctx_add_lesson`:
`ctx_query`, `ctx_hydrate`, `ctx_semantic_search`, `ctx_enqueue`.

Likely fix is to drop the shell entirely — `Open3.capture3` accepts an argv
array, so `capture3(CTX_BIN, *args)` needs no escaping at all; the only reason
for `bash -c` here is sourcing `env.sh` first, which could be done by reading
the env rather than interpolating a command line. Operator's call.

**Worth auditing:** how many existing rows already carry mangled text.

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
