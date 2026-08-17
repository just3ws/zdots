---
name: interop-registry
description: Audit or update the cross-repo interop registry (docs/cross-repo-interop.md) — the external, non-platform repos (wwworkremote/core, just3ws.github.io, ...) with a real dependency on zdots. Use for "check interop", "align the repos", "audit cross-repo docs", "add/remove a member of the coordination system", or after finding evidence a new external repo depends on zdots (or vice versa).
---

# /interop-registry — cross-repo interop, kept honest

`/platform-sync` and `/docs-sync` own the four-repo platform
(zdots/adots/vdots/my). This skill owns a different, smaller set: **external
repos that have a real dependency on zdots**, tracked in
`docs/cross-repo-interop.md`. It exists because that registry was built once
(2026-08-17) by manually cross-checking O2 traces against each repo's own
docs, and manual work that isn't given a repeatable process rots.

**The one rule everything else follows: evidence before documentation.**
A plausible-sounding relationship is not a member. Every row in the registry
traces to something checkable — a trace ID, a log line, live bus traffic, or
an explicit statement in the other repo's own tracked docs. This skill exists
*because* the alternative (inventing a schema or a dependency that "should"
exist) already produced wrong output once this session — see the corrected
lesson in context-engine (`zdots-ctx query "correction wwworkremote just3ws"`).

## Audit mode (default — "check interop", "align the repos")

For each row in `docs/cross-repo-interop.md`:

1. **Re-verify the evidence still holds.**
   - HTTP/service dependency → re-check with a fresh probe (`curl`) or a
     fresh O2 trace query (`zdots-o2-query sql --type traces "..."`),
     don't just trust the old trace ID forever.
   - Bus channel → `zdots-ctx bus-channels --as mike`, confirm the channel
     and message count still look alive (or note if it's gone quiet).
   - Doc-only claim (their side references zdots but no trace exists yet) →
     leave as documented-but-unconfirmed; don't silently promote to
     "confirmed" without evidence.
2. **Re-read both sides' docs.** If the other repo's doc file listed in the
   registry has moved, been renamed, or no longer mentions the relationship,
   that's a finding — flag it, don't assume the registry row is still right.
3. **Check for undocumented relationships.** Grep the other repos' docs for
   "zdots" and grep zdots' O2 traces for the other repos' service names —
   the same two-pronged check that built the registry originally. A new
   relationship found this way needs Add mode (below) before it's real.
4. Report a table: row → still-evidenced / stale / gone, one line each.
   Fix zdots-side doc drift directly (it's zdots' own docs). Anything on the
   *other* repo's side is theirs — note it, don't edit their repo without
   being asked.

## Add mode — a new member joins the coordination

Only after finding real evidence (not before):

1. Confirm the evidence independently — a trace, a log line, or an explicit
   statement in the *other* repo's own tracked docs (not a guess from
   "this seems like it would be useful").
2. Add one row to `docs/cross-repo-interop.md` with the evidence and the
   doc file(s) on the other side that already describe it (or note "not yet
   documented there" if it's one-sided).
3. Add the corresponding one-line note to whichever zdots doc it touches
   (`docs/llama-cpp.md`-style "known consumer" note, `docs/message-bus.md`
   channel flag, `docs/local-url-routing.md` topology row — pick by what the
   dependency actually is, don't invent a new doc file for one line).
4. Add a Lesson to context-engine (`zdots-ctx add-lesson "..." "platform
   topology / local service mesh" <tags>`) so it's queryable outside this
   file too. Verify with `zdots-ctx query` before considering it done.
5. Run `bats tests/docs_contract.bats` and `bin/secret-scan` before
   committing — same gate as any other doc change.

## Remove mode — a member's relationship ends

Don't delete the row silently — a stale-but-present row that nobody
remembers removing is how the next agent gets confused, but so is a row that
vanished with no trail.

1. Confirm it's actually gone (audit mode above), not just quiet — a channel
   with no recent traffic isn't necessarily dead; check with the operator if
   unsure whether "quiet" means "removed" or "just not used this week."
2. Move the row to a `## Retired` section in the registry with the date and
   why (evidence expired, repo archived, dependency removed on purpose,
   etc.) — don't just delete it, the history is the point.
3. Remove the corresponding zdots-side doc note (the "known consumer" line,
   the channel flag) since it's no longer true.
4. Add a corrective Lesson to context-engine, same pattern as any correction
   this session used — supersede, don't silently overwrite.

## Change mode — a relationship's shape changes

(Port moves, endpoint renamed, channel renamed, a read-only export becomes
two-way, etc.) Treat as Remove-the-old-row + Add-the-new-row, both with their
own evidence — a changed relationship gets the same evidence bar as a new
one, not an assumed carry-over of the old evidence.

## What this skill does not do

- Does not touch `wwworkremote/core` or `just3ws.github.io` directly unless
  explicitly asked — they're not zdots' repos to edit. Note findings about
  their side; let the operator (or a session rooted there) make the edit.
- Does not extend Astronomicon (decision-007) epoch-stamping to external
  repos — that's a real scope change to a platform decision, not something
  this skill decides unilaterally. Flag it as a question if it comes up.
- Does not invent a relationship to fill out the registry. An empty "not a
  member" section (see the registry's own "Explicitly NOT members" list) is
  a valid, useful finding — record what's checked-and-absent, not just
  what's present.
