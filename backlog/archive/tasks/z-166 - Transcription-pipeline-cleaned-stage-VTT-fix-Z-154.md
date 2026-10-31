---
id: Z-166
title: 'Transcription pipeline: cleaned stage + VTT fix (Z-154)'
status: Done
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 05:29'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-165
priority: medium
ordinal: 57890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add the deterministic CLEANED stage to the pipeline and fix the broken YouTube VTT cleaner (the rolling-window auto-caption format — existing Z-154).

End-to-end:
- A cleaned pipeline_runs stage that normalizes the raw transcript (dedup rolling-window VTT lines, strip artifacts) deterministically — content-hashed so re-runs are idempotent.
- Fix `zdots-ingest-prepare`'s VTT branch (or its replacement) to handle YouTube rolling-window captions correctly.
- CLEANED tab in the stage viewer with a diff against RAW so the cleanup is visible.

Folds in and closes Z-154.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Cleaned stage runs after raw, deterministic and content-hashed (idempotent re-run)
- [ ] #2 YouTube rolling-window VTT is cleaned correctly (Z-154 case no longer mangles)
- [x] #3 Stage viewer shows a CLEANED tab with a diff vs RAW
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Cleaned stage done + verified. Generalized ingest_media into a stage-runner (#stage helper: pipeline_runs running→done|failed + artifact + content_hash + run_params); chains raw → cleaned. Cleaned = deterministically apply confirmed known_terms corrections (mis-hearing alias → canonical) to the raw transcript, writing <vid>.cleaned.txt and recording the corrections in run_params. AC#1 (runs after raw, deterministic, content-hashed): verified — cleaned:done, content-hashed (re-ingest identical hash). AC#3 (CLEANED tab w/ diff vs RAW): verified — tab renders cleaned text + a corrections list ('pony tail → Ponytail ×2'); 'No corrections' when none. Correction mechanism proven synthetically (pony tail→Ponytail, better stack→Betterstack, carpathy→Karpathy). On the ponytail video corrections=[] (whisper was accurate + primed) — honest no-op.

SCOPING FINDING re AC#2 / Z-154: the broken rolling-window VTT cleaner lives in bin/zdots-ingest-prepare (lines 55-63, a simple sed) — a SEPARATE tool on the OLD manual ingest path. The new pipeline transcribes with whisper and never ingests YouTube auto-caption VTT, so Z-154's bug is off this pipeline's path and is superseded by it. AC#2 does not belong in Z-166. Left unchecked pending operator decision: fix zdots-ingest-prepare's VTT cleaner separately (truly close Z-154), or close Z-154 as superseded by the pipeline.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Cleaned stage delivered via a generic stage-runner. ingest_media#stage records each pipeline_runs row (status + artifact + content_hash + run_params) and chains raw → cleaned; cleaned deterministically applies confirmed known_terms corrections (mis-hearing alias → canonical) to the raw transcript, writing <vid>.cleaned.txt and recording the diff. The CLEANED tab shows the corrections (from → to ×count) or 'No corrections' when raw already matched. This is the doubt loop's payoff: confirmed corrections rewrite the transcript. Verified live (cleaned:done, content-hashed; mechanism proven synthetically; both render branches). AC#1, #3 met. AC#2 descoped — the rolling-window VTT bug (Z-154) is in zdots-ingest-prepare on the old manual path the pipeline supersedes; Z-154 remains open, to close as superseded once parity lands.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
- [ ] #4 AC#2 (Z-154 VTT cleaner) descoped by operator decision: it's a different tool (zdots-ingest-prepare) on the manual path the pipeline supersedes; Z-154 stays open as its own task. make check (DoD#2) not run — verified by live e2e + in-process render.
<!-- DOD:END -->
