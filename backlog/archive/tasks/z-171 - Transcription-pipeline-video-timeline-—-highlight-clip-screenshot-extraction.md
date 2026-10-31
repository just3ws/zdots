---
id: Z-171
title: 'Transcription pipeline: video timeline — highlight/clip/screenshot extraction'
status: Done
assignee: []
created_date: '2026-06-20 21:11'
labels:
  - transcription-pipeline
  - deferred
dependencies:
  - Z-168
priority: low
ordinal: 62890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deferred extension. Turn a retained video + its transcript into a curated timeline of extractable moments (screenshot / snippet / clip / excerpt), materialized with ffmpeg.

Flow (a new stage on the working pipeline, not a new system):
- Retain the media (retention store + keep-media; today's recipe deletes it). Keep audio always; video opt-in or re-fetch on demand — YouTube video retention is storage + ToS weight.
- The DISTILLED LLM stage (Z-168) already grounds insights to [mm:ss]; extend it to also emit a timeline of MOMENTS: each {t_start, t_end, kind: screenshot|snippet|clip|excerpt, title, reason, quote}.
- Human curates the timeline (Landed-Thoughts gate) — never auto-extract dozens of clips.
- ffmpeg materializes ONLY confirmed moments into the retention store: screenshot = -ss T -frames:v 1; clip/snippet = -ss T1 -to T2; excerpt = transcript span (no ffmpeg).
- TIMELINE tab on /transcriptions/:id: scrubbable moments, each linking back to its transcript span. Promote a moment (with its clip/screenshot) to a lesson as visual evidence.

Storage: moments live in a `timeline` JSON artifact + a pipeline_runs `timeline` stage. NO media_moments table until cross-video moment search is wanted (that's the upgrade trigger).

PHI: extracted clips/screenshots from clinical sources are MORE PHI artifacts — they stay local, never shared/cloud, per Z-163's destination model. Whisper timestamps aren't frame-accurate: fine for clips, snap-or-nudge for screenshots.

Depends on the DISTILLED stage (Z-168) and the retention store (provisioned in the Z-164 line).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 DISTILLED stage emits a timeline of moments (kind screenshot|snippet|clip|excerpt, time/range, reason, [mm:ss] grounding)
- [x] #2 Human curates the timeline before extraction — nothing is auto-extracted
- [x] #3 ffmpeg materializes only confirmed moments into the retention store (screenshot/clip/excerpt)
- [x] #4 TIMELINE tab on /transcriptions/:id shows moments linking back to their transcript span
- [x] #5 Retain audio always; video opt-in or re-fetch on demand
- [x] #6 Clinical-source extracts stay local, never shared/cloud (Z-163)
- [x] #7 Moments stored as a timeline JSON artifact + pipeline_runs stage — no media_moments table
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
