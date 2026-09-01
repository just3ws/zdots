---
id: Z-330
title: Retire the 'transcription' job type — superseded by transcribe_chunk
status: To Do
assignee: []
created_date: '2026-09-01 13:05'
updated_date: '2026-09-01 13:18'
labels:
  - agent-reported
dependencies: []
priority: low
ordinal: 205895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Gate 8 of zdots-heal (2026-09-01): pipeline-events.jsonl shows job_type 'transcription' at 10 started / 10 failed (RuntimeError), last activity 2026-07-25. It has been fully replaced by 'transcribe_chunk' (6 started / 0 failed, current). The old code path, its worker dispatch entry, and any schema/enqueue references are dead weight and produce misleading failure stats in Gate 8. Remove or explicitly deprecate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 'transcription' job type removed from worker dispatch (or documented as deprecated with a guard that refuses to enqueue it)
- [ ] #2 No regression in transcribe_chunk path — bats tests green
- [ ] #3 Gate 8 jq failure view no longer reports a 'transcription' group (or reports it as intentionally retired)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scoping (zdots-heal 2026-09-01): lib/zdots/jobs/transcription.rb (44 lines) registers job type 'transcription', shells out to recipes/yt-transcribe. NO enqueuers remain (grep of bin/ + lib/ for enqueue/'transcription' finds only doc["transcription"], an unrelated whisper JSON key). Superseded by transcribe_chunk (203 lines, registered, 0 failures). Test touchpoints: tests/reprocess_cli.bats:8 (comment only — 'enqueues a transcription'), tests/llama_integration.rb:64 (comment only). recipes/yt-transcribe (10.6K) still present — check if anything else calls it before removing. Retire = delete transcription.rb + its Jobs.register line, refresh the two test comments, decide on the recipe. Small + low-risk but left for a focused pass.
<!-- SECTION:NOTES:END -->
