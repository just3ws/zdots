---
id: Z-168
title: 'Transcription pipeline: distilled stage + scrub-before-AI + inline edit'
status: To Do
assignee: []
created_date: '2026-06-20 18:12'
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
- [ ] #1 Distilled stage produces structured insights with [mm:ss] grounding from the cleaned transcript
- [ ] #2 Transcript content passes the PHI scrubber before any ai-query call, keyed to destination (Z-163)
- [ ] #3 DISTILLED tab renders the insights and allows inline edit
- [ ] #4 Saving an edit writes a new content-hashed distilled artifact and invalidates downstream
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
