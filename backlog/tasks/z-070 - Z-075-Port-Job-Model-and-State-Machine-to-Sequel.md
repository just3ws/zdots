---
id: Z-070
title: 'Z-075: Port Job Model and State Machine to Sequel'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
updated_date: '2026-05-15 03:16'
labels:
  - industrialization
  - ruby
  - postgres
dependencies:
  - Z-069
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate the job state machine from manual SQL/Bash to a declarative Sequel model. This includes porting the claim_next_job and fail_job logic to Ruby, providing a more robust and testable foundation for complex job management.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 lib/zdots/models/job.rb implements the claim, complete, and fail logic using Sequel.
- [x] #2 Sequel migrations created to track schema versions instead of etc/db/migrations manual files.
- [x] #3 zdots-ctx status --json reports database state via Ruby model.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported Job Model and State Machine to Sequel.
- Implemented `Zdots::Models::Job`, `Lesson`, and `Methodology` using Sequel.
- The `Job` model wraps the PostgreSQL stored procedures (`claim_next_job`, `fail_job`, `complete_job`) for atomic state transitions.
- Created `sbin/zdots-brain` as the core Ruby logic engine.
- Refactored `zdots-ctx status` to delegate to the Ruby core, providing consistent human and JSON reporting.
- Silenced OTel diagnostic noise in CLI output.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
