---
id: Z-070
title: 'Z-075: Port Job Model and State Machine to Sequel'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
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
- [ ] #1 lib/zdots/models/job.rb implements the claim, complete, and fail logic using Sequel.
- [ ] #2 Sequel migrations created to track schema versions instead of etc/db/migrations manual files.
- [ ] #3 zdots-ctx status --json reports database state via Ruby model.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
