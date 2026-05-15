---
id: Z-071
title: 'Z-076: Port Transcription Job to Ruby Class'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
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
- [ ] #1 lib/zdots/jobs/transcription.rb implements the YouTube download and FFmpeg logic.
- [ ] #2 Job execution emits nested OTel spans via Ruby SDK.
- [ ] #3 Worker dynamically loads and executes the job class based on the type column.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
