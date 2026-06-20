---
id: Z-165
title: 'Transcription pipeline: stage viewer — raw transcript'
status: To Do
assignee: []
created_date: '2026-06-20 18:12'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-164
priority: medium
ordinal: 56890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Per-source page at `/transcriptions/:id` showing the raw transcript content for a source, with a tabbed content area (RAW tab only for now; later slices add CLEANED/DISTILLED tabs).

Reads the raw artifact recorded by the ingest slice; renders text with its `[mm:ss]` offsets. Read-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 /transcriptions/:id renders the raw transcript for a completed source
- [ ] #2 Content area is tabbed and ready to host additional stage tabs
- [ ] #3 Page shows source identity + per-stage status from pipeline_runs
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
