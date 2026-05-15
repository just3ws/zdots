---
id: Z-068
title: 'Z-073: Implement Autonomous Job Chaining'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 02:35'
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
- [ ] #1 PostgreSQL trigger 'tr_chain_completed_jobs' automatically enqueues follow-up jobs based on type.
- [ ] #2 A completed 'transcription' job automatically enqueues a 'distill' job with the output path in the payload.
- [ ] #3 Worker is updated to store output metadata in the jobs table upon completion.
- [ ] #4 Verified end-to-end autonomous flow: Transcription -> Distillation -> Embedding.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
