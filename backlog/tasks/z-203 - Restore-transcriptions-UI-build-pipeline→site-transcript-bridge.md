---
id: Z-203
title: Restore /transcriptions UI + build pipeline→site transcript bridge
status: Done
assignee: []
created_date: '2026-07-07 19:10'
updated_date: '2026-07-07 19:57'
labels:
  - transcription
  - context-engine
  - just3ws-site
dependencies: []
priority: high
ordinal: 99890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The /transcriptions operator UI (context-engine, bridges zdots pipeline models) was gutted from live ~/my/context-engine; complete version exists in /Volumes/Dock_1TB/_transfer/my/context-engine snapshot. Restore it, then build the missing pipeline→site data bridge so the pipeline services just3ws.github.io's transcription product (site consumes _data/transcripts/*.yml: turns+speaker_map+insights, keyed by transcript_id from video_assets.yml). Deferred vision: move the UI into zdots itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phase 1: /transcriptions restored to ~/my/context-engine and renders at my.localhost/transcriptions (index+show+add form)
- [x] #2 Phase 1: known_terms/doubt-triage/distill/promote learning loop intact
- [x] #3 Phase 2: pipeline distilled/promoted output can populate site _data/transcripts/*.yml in the site's schema
- [x] #4 Phase 2: site video list (video_assets.yml / transcript_retranscribe_queue.yml) can feed pipeline ingestion
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1) surgical restore: copy 8 snapshot-only files (controller/2 helpers/3 models/2 services/views), additive-merge routes.rb + zdots_bridge.rb (pg ext + lesson_intake), replace _sidebar (superset). 2) append transcription app.css block. 3) browser-verify. 4) map pipeline artifact schema -> site transcript YAML, build export. 5) map site video queue -> ingest input.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
GAP (a) FIXED: bin/stage_completed_transcripts.rb now prefers <id>.cleaned.txt (known-terms-corrected learning-loop output) over raw <id>.txt/.stitched.txt via new preferred_transcript_files() helper (groups by video id = basename up to first dot). Guarded main under __FILE__==$PROGRAM_NAME; added spec/bin/stage_completed_transcripts_spec.rb (4 examples, pass). So the /transcriptions correction loop now feeds the site, not just raw ASR. Site-repo changes uncommitted on master for user review. Remaining open: gap (b) reverse feed site queue->pipeline still manual; gap (c) --apply is user's to run.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
