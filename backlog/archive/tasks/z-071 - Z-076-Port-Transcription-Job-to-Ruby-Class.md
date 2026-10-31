---
id: Z-071
title: 'Z-076: Port Transcription Job to Ruby Class'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
updated_date: '2026-05-15 03:32'
labels:
  - industrialization
  - ruby
  - automation
dependencies:
  - Z-070
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port the transcription job logic from Bash to a modular Ruby class. This allows for better error handling, structured logging, and deeper OTel integration for the heavy-lifting parts of the pipeline.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 lib/zdots/jobs/transcription.rb implements the YouTube download and FFmpeg logic.
- [x] #2 Job execution emits nested OTel spans via Ruby SDK.
- [x] #3 Worker dynamically loads and executes the job class based on the type column.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported Transcription Job and Worker logic to Ruby.
- Implemented `Zdots::Jobs::Base` and `Zdots::Jobs::Transcription` modular classes.
- The Ruby worker now dynamically loads the appropriate job class and executes it with streaming output.
- Integrated OpenTelemetry spans directly into the Ruby job execution lifecycle.
- Ported `enqueue`, `jobs`, `add-methodology`, and `add-lesson` to the Ruby core.
- Verified successful execution of the YouTube transcription pipeline via the Ruby worker.
- Cleaned up Bash script complexity by delegating core logic to `sbin/zdots-brain`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
