---
id: Z-330
title: Retire the 'transcription' job type — superseded by transcribe_chunk
status: To Do
assignee: []
created_date: '2026-09-01 13:05'
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
