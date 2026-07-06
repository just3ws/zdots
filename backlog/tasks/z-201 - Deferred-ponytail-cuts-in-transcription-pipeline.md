---
id: Z-201
title: Deferred ponytail cuts in transcription pipeline
status: To Do
assignee: []
created_date: '2026-07-06 13:27'
labels:
  - request
dependencies: []
references:
  - commit 545dc57
priority: low
ordinal: 97890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Over-engineering surfaced during the anti-loop/splice hardening; deferred pending owner call. Low priority, no correctness impact.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decide keep/cut on the Mermaid pipeline diagram in lib/zdots/jobs/ingest_media.rb; if cut, remove the generator (~30 lines), its drift test, and the generated .mmd artifact
- [ ] #2 JSON_FLAG two-line block in recipes/yt-transcribe deduped or left with a note explaining why
- [ ] #3 Record a keep/cut decision on optional fail-fast DiarizationContract validation inside the just3ws importer diarization_block_for
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
