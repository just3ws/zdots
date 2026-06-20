---
id: Z-170
title: 'Transcription pipeline: promote distilled insight to lesson'
status: To Do
assignee: []
created_date: '2026-06-20 18:12'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-168
priority: medium
ordinal: 61890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Close the virtuous loop. Edited distilled content is promoted into the Knowledge Layer and becomes semantically searchable.

End-to-end:
- From the DISTILLED/edited content, promote to a `lessons` row reusing the existing `LessonIntake` path (source_type, source_trace_id linking back to the pipeline run + source `[mm:ss]`).
- Auto-embed on promotion (existing llama-embed job) so the lesson is immediately surfaced by `zdots-ctx query --semantic`.
- PROMOTED stage recorded in pipeline_runs; the source shows as complete in /transcriptions.

Provenance: the lesson carries a backlink to the source (title, timestamp, url/path, content hash).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Promoting edited distilled content creates a lessons row via LessonIntake with source backlink + [mm:ss]
- [ ] #2 Promotion triggers the existing embed job; the lesson is returned by zdots-ctx query --semantic
- [ ] #3 PROMOTED stage recorded; source shows complete in /transcriptions
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
