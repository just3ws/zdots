---
id: Z-068
title: 'Z-073: Implement Autonomous Job Chaining'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 02:35'
updated_date: '2026-05-15 02:41'
labels:
  - intelligence-suite
  - postgres
  - automation
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement autonomous job sequencing within the PostgreSQL brain. Use database triggers to automatically enqueue the next logical task when a job completes, starting with chaining 'distill' jobs after successful 'transcription' jobs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PostgreSQL trigger 'tr_chain_completed_jobs' automatically enqueues follow-up jobs based on type.
- [x] #2 A completed 'transcription' job automatically enqueues a 'distill' job with the output path in the payload.
- [x] #3 Worker is updated to store output metadata in the jobs table upon completion.
- [x] #4 Verified end-to-end autonomous flow: Transcription -> Distillation -> Embedding.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented Autonomous Job Chaining in the PostgreSQL Intelligence Suite.
- Created migration `008_autonomous_chaining.sql` adding the `tr_chain_completed_jobs` trigger.
- When a `transcription` job completes, the database automatically enqueues a `distill` job, propagating the video URL and source metadata.
- Implemented the `distill` job type in the `zdots-ctx worker`, which reads the transcript file, uses local AI to extract engineering lessons, and saves them to the database.
- Leveraged existing logic where `add-lesson` automatically enqueues an `embed` job, completing a 3-stage autonomous pipeline: Transcription -> Distillation -> Embedding.
- Verified the flow by mocking a transcription completion and observing the automatic creation of the follow-up jobs.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
