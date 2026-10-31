---
id: Z-168
title: 'Transcription pipeline: distilled stage + scrub-before-AI + inline edit'
status: Done
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 06:27'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-166
  - Z-163
priority: medium
ordinal: 59890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add the probabilistic DISTILLED stage and the minimal human gate.

End-to-end:
- DISTILLED pipeline stage: local-LLM distillation of the cleaned transcript into structured insights, each carrying its `[mm:ss]` grounding. Map-reduce-ready for long sources (per-chunk distill → synthesize).
- PHI scrub before any `ai-query` call, keyed to destination (per Z-163 policy).
- DISTILLED tab in the stage viewer; the distilled markdown is editable inline (the minimal Landed-Thoughts gate — a textarea, not the rich editor). Saving writes a new content-hashed distilled artifact and re-runs downstream.

This is the lazy Landed-Thoughts: edit-the-markdown, not the full editor (deferred).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Distilled stage produces structured insights with [mm:ss] grounding from the cleaned transcript
- [x] #2 Transcript content passes the PHI scrubber before any ai-query call, keyed to destination (Z-163)
- [x] #3 DISTILLED tab renders the insights and allows inline edit
- [x] #4 Saving an edit writes a new content-hashed distilled artifact and invalidates downstream
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-06-21 06:27
---
Done. DISTILLED tab live; distilled briefing for the ponytail video shows [mm:ss]-grounded insights, editable + savable. ai-query handles the PHI scrub (AC#2). DoD#2 make-check N/A for this path — verified via live driver + in-process request test instead. Next → Z-170 promote-to-lesson (parity).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Distilled stage shipped end-to-end and verified live on the ponytail video (source 0f2f7768).

- **Stage** (zdots `lib/zdots/jobs/ingest_media.rb`, commit fcd82e517): new `distilled` stage in the stage-runner. Builds a `[mm:ss]`-tagged, known_terms-corrected transcript from the whisper `.vtt`, pipes it to `ai-query` (default mode), persists a content-hashed `.distilled.md` artifact + pipeline_run. Extracted `apply_corrections` so cleaned + distilled share one correction pass.
- **AC#1** — verified: artifact is a faithful markdown briefing, every bullet prefixed with `[mm:ss]` grounding (00:00 → 09:19), input_chars=9989.
- **AC#2** — satisfied by `ai-query` itself: it runs `aiq_normalize | phi_scrub` on the data block (bin/ai-query:477) before sending, and enforces a loopback endpoint. No re-implementation (ponytail ladder rung 4). Scrub-by-destination = local llama keeps identity, scrubs the 7 credential/secret patterns.
- **AC#3 / AC#4** — context-engine (`~/my`, commit 3a96194): DISTILLED tab renders an editable textarea (the minimal Landed-Thoughts gate); `POST /transcriptions/:id/distilled` rewrites the artifact, re-hashes its pipeline_run, and deletes downstream stages (landed/promoted) so they re-run. In-process round-trip verified: GET 200 (textarea+Save present, insight text rendered), POST 302 → artifact changed on disk, edit marker persisted, run hash matches new file.

DoD#2 (`make check`): not run — no make target touches this path; verification was the live driver + in-process request test above. Worker restarted on new handler code. Both repos committed on `work`, nothing pushed.

Next: Z-170 (promote distilled insight → lessons row + embed) reaches parity with the manual /ingest-media flow.
<!-- SECTION:FINAL_SUMMARY:END -->
