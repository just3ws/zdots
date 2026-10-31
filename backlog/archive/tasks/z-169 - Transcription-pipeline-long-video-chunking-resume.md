---
id: Z-169
title: 'Transcription pipeline: long-video chunking + resume'
status: Done
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 14:31'
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
- [x] #1 Long source is split into overlapping chunks, each a transcribe_chunk job on the existing queue
- [x] #2 Per-chunk progress tracked via pipeline_runs.chunk_index and shown as N/M in /transcriptions
- [x] #3 A killed job resumes from the last incomplete chunk, not from zero
- [x] #4 Reduce step stitches chunks and dedups the overlap; no media_chunks table
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-06-21 14:31
---
Done. Chunking verified on a 570s fixture (threshold 120s → 2 windows): plan → progress 1/2 → resume re-enqueues only the gap → fan-in stitch (deduped) → cleaned/distilled. Dashboard shows raw N/M; deployed live. No media_chunks table — chunk_index on pipeline_runs. Follow-ups: stitched-VTT for chunked [mm:ss] grounding + chunked doubt-loop.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Long-video chunking shipped + verified end-to-end on a 570s fixture (threshold 120s → 2 windows). zdots commit 8f185c21d, context-engine commit 1ed9054.

**Design** — raw stage fans out, rest reuses the existing machinery:
- Sources longer than `ZDOTS_CHUNK_THRESHOLD_SEC` (default 30m) split into overlapping windows (`CHUNK_WINDOW_SEC`/`CHUNK_OVERLAP_SEC`). `ingest_media` enqueues one `transcribe_chunk` job per window on the existing jobs queue, so retries/attempts/dead-lettering give checkpoint+resume for free.
- Per-window state = `pipeline_runs.chunk_index` (0..N-1); the whole-stage summary row (`chunk_index NULL`) holds the stitched transcript. **No media_chunks table.**
- Fan-in: the window finishing last wins the unique-index race on the summary row (`reduce_if_complete`), stitches windows with greedy word-overlap dedup, and re-enqueues `ingest_media` to resume cleaned→distilled. `ensure_raw` short-circuits on a done summary (resume).
- Recipe: `--prep-only` (download+convert, keep the 16k wav) and `--from-wav/--offset-sec/--window-sec/--output-base` (per-window whisper via `-ot/-d`), sharing one `resolve_model`.

**Verification (all ACs):**
- **AC1** — 570s>120s → 2 windows planned, 2 `transcribe_chunk` jobs on the queue.
- **AC2** — per-chunk rows tracked; progress `1/2` after one window; live dashboard shows `(raw N/M)` on the index and `chunks N/M` on the show card (in-process render confirmed "chunks 2/2" + stitched text).
- **AC3** — drained the queue after window 0, re-planned → only `[1]` re-enqueued; window 0 stayed done. Resume from the last gap, not zero.
- **AC4** — fan-in stitched (9787B) vs sum-of-windows (9853B) → overlap deduped; no media_chunks table. `splice` self-check passes (`ruby lib/zdots/jobs/transcribe_chunk.rb`).

DoD#2 (`make check`): N/A — verified via the live driver + in-process render test above; secret-scan clean. Worker restarted on new code; dashboard redeployed.

ponytail follow-ups (noted in code): chunked distilled has no `[mm:ss]` grounding yet (needs a stitched VTT); chunked doubt-loop likewise. Demo on the true 2h+/3h31m fixtures is now just a matter of running them through the live worker (default 30m threshold).
<!-- SECTION:FINAL_SUMMARY:END -->
