---
id: Z-169
title: 'Transcription pipeline: long-video chunking + resume'
status: To Do
assignee: []
created_date: '2026-06-20 18:12'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-164
priority: medium
ordinal: 60890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make multi-hour sources work without exceeding whisper memory or losing progress on failure.

End-to-end:
- The ingest job plans chunks (windowed audio with overlap) and enqueues one `transcribe_chunk` job per chunk — reusing the existing jobs queue, so fan-out parallelism, checkpoint/resume, and dead-lettering ride the existing fail_job/attempts machinery for free.
- Per-chunk state via `pipeline_runs.chunk_index` (no separate media_chunks table). Raw-stage progress = COUNT(done chunks)/COUNT(*), shown as "raw: 12/45" in /transcriptions.
- A reduce step stitches chunks (dedup the overlap). Resume = only un-done chunk jobs remain claimable.

Demo on the 2h+ fixture (lXUZvyajciY) and ideally the 3h31m one (7xTGNNLPyMI).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Long source is split into overlapping chunks, each a transcribe_chunk job on the existing queue
- [ ] #2 Per-chunk progress tracked via pipeline_runs.chunk_index and shown as N/M in /transcriptions
- [ ] #3 A killed job resumes from the last incomplete chunk, not from zero
- [ ] #4 Reduce step stitches chunks and dedups the overlap; no media_chunks table
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
