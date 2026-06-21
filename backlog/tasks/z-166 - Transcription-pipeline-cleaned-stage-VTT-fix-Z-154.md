---
id: Z-166
title: 'Transcription pipeline: cleaned stage + VTT fix (Z-154)'
status: To Do
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 05:27'
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
