---
id: Z-204
title: Add primer text / pre-context to media sources
status: Done
assignee: []
created_date: '2026-07-09 08:41'
updated_date: '2026-07-12'
labels:
  - transcription
  - context-engine
dependencies: []
priority: high
ordinal: 99895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add plain text (like song lyrics or specific domain context) when starting a transcription, and be able to edit this text on the transcription page and restart the process. This text should be fed into Whisper (transcription) as a prompt, and also into the LLM (distilled) stage as context.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phase 1: Database and UI form to add/edit primer_text for MediaSources
- [x] #2 Phase 2: Pipeline integration (ingest_media.rb) to feed primer_text into Whisper (known_vocabulary) and LLM prompt
- [x] #3 Phase 3: Retry mechanism on update
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Generate migration for primer_text on media_sources.
2. Update transcriptions controller and views (add_form and show) to support primer_text and update_primer action.
3. Update ingest_media.rb to inject primer_text into known_vocabulary and LLM context task string.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- 2026-07-12: The pipeline was failing with `Broken pipe @ rb_sys_fail_on_write - <STDOUT>` during raw/distill stages when run under `launchd` via `zdots-worker`. This was due to `puts out` attempting to write megabytes of ffmpeg/whisper output to `STDOUT` at once, which broke the pipe that `launchd` uses to forward logs. Fixed by appending directly to the worker log file `File.open(..., "a") { |f| f.puts out }` inside `transcribe_raw`.
- 2026-07-12: Ran a full end-to-end verification (`reprocess --transcribe`) on the DHH interview using the primer_text. Confirmed the text is properly passed through to both Whisper and Claude (`ai_distill`), successfully guiding the AI to extract insights of the back-and-forth interview exchange, even when the diarization mock returned single-speaker (`SPEAKER_00`).
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
