---
id: Z-166
title: 'Transcription pipeline: cleaned stage + VTT fix (Z-154)'
status: To Do
assignee: []
created_date: '2026-06-20 18:12'
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
- [ ] #1 Cleaned stage runs after raw, deterministic and content-hashed (idempotent re-run)
- [ ] #2 YouTube rolling-window VTT is cleaned correctly (Z-154 case no longer mangles)
- [ ] #3 Stage viewer shows a CLEANED tab with a diff vs RAW
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
