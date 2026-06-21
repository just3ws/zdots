# ADR-0003: scoped, opt-in cloud distill for public-video transcripts

**Status:** Accepted
**Date:** 2026-06-21

## Context

The transcription pipeline's `distilled` stage turns a (long) transcript into a
knowledge briefing via the local LLM (`ai-query` → llama.cpp, 14B). Two facts
created pressure to allow a cloud model for this one stage:

1. **Quality/latency.** A frontier model (Claude Haiku 4.5, 200K context)
   produces a stronger briefing in one shot than the local map-reduce, with no
   windowing. The operator asked for Haiku on "the analysis."
2. **This is a PHI-adjacent work machine.** `ZDOTS_AI_MODE=local` is enforced
   by `.zdots.work`; `lib/ai_boundary.bash` blocks non-loopback endpoints in
   local mode; Claude Code (a cloud tool) is approved for work use,
   but corporate-approved ≠ PHI/BAA-cleared.

The naive change — point the shared `ai-query` at the cloud — is wrong: it has
callers we can't see (`zdots-ask`, the doubt loop, other jobs), so it would
route *all* of them to the cloud, including non-public content.

## Decision

Add an **opt-in cloud branch inside the `distilled` stage only**
(`lib/zdots/jobs/ingest_media.rb`). `ai-query`, `ai_boundary.bash`, and every
other caller are untouched. The branch sends a byte to the cloud only when
**all** of these hold:

1. **Flag on** — `ZDOTS_DISTILL_CLOUD=1` (default off → 100% local, prior behavior).
2. **Public content** — `media_source.source_type ∈ {youtube, vimeo}`,
   hard-asserted. A local-file / non-public ingest can never take the cloud path.
3. **PHI Scrubber first** — the transcript passes through `Zdots::AI::PhiScrubber`
   before egress; a suppress-flagged pattern raises and falls back to local.
4. **Key at runtime** — `ANTHROPIC_API_KEY` loaded from the macOS Keychain at
   call time (`security find-generic-password`), never in the plist, logs, or
   git. Absent key → fall back to local.

Any cloud error falls back to local — the job never dies on a cloud failure.
The model that produced each briefing is recorded in
`pipeline_runs.run_params` (`"cloud:claude-haiku-4-5"` vs `"local"`), and a line
is written to the worker log — the audit trail for what left the machine.

Implementation uses Ruby stdlib `net/http` (one POST to
`https://api.anthropic.com/v1/messages`), not the `anthropic` gem — to avoid
adding a dependency to the PHI-adjacent worker's bundle for a single text call.

Model: `claude-haiku-4-5` (override via `ZDOTS_DISTILL_CLOUD_MODEL`). Haiku's
200K context fits a whole transcript, so the cloud path skips the local
map-reduce windowing.

## Consequences

- **What stays prohibited:** PHI to the cloud. The public-content gate is the
  load-bearing boundary; the PHI Scrubber is defense-in-depth. Enabling cloud
  distill is **not** a green light for PHI egress — that needs an explicit BAA
  decision, separately.
- **Operator turns it on** by provisioning the Keychain key and setting
  `ZDOTS_DISTILL_CLOUD=1` in the worker's environment. Until both, the code is
  inert.
- **Verification:** the gate is covered by `tests/ingest_media_cloud_distill.bats`
  — a local-file source is refused the cloud path even with the flag on and a
  key present (the negative test), while a public source + key is eligible.

## Related

ADR-0001 (nginx not in the AI-query path), ADR-0002 (PHI Scrubber Go binary),
the PHI Operating Mode (AGENTS.md §10), [[project-claude-code-corporate-approval]].
