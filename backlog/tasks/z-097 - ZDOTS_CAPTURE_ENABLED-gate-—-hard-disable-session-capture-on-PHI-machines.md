---
id: Z-097
title: ZDOTS_CAPTURE_ENABLED gate — hard-disable session capture on PHI machines
status: To Do
assignee: []
created_date: '2026-05-23 21:40'
labels:
  - phi-safe
  - security
  - agent-ready
milestone: m-5
dependencies: []
modified_files:
  - bin/zdots-ctx
  - .zdots.env
  - lib/ai_boundary.bash
priority: high
ordinal: 810
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The `zdots-ctx capture` command distills shell session context (history + traces) via LLM and stores the result in the `lessons` and `session_residue` tables. On a PHI machine this is a risk: any PHI that passed through the shell session during the capture window could be distilled and permanently stored in the DB.

`ZDOTS_CAPTURE_ENABLED` already exists as an env var but is only advisory — `bin/zdots-ctx` does not enforce it. On a PHI machine the default must be 0 and the gate must be hard (not a warning).

The `Zdots::AI.client` gate already enforces locality for Ruby callers. This task adds the equivalent capture gate at the bash entrypoint.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 bin/zdots-ctx capture exits 2 immediately when ZDOTS_CAPTURE_ENABLED=0, printing a clear message naming the env var
- [ ] #2 zdots_audit_log capture_blocked fires on exit — visible in os_log stream
- [ ] #3 ZDOTS_CAPTURE_ENABLED defaults to 0 in .zdots.env (not 1)
- [ ] #4 Work machine profile (Z-084) sets ZDOTS_CAPTURE_ENABLED=0 explicitly so it cannot be accidentally inherited as 1
- [ ] #5 zdots-ctl check reports capture status (enabled/disabled) as part of its PHI section
- [ ] #6 Existing capture flow is unchanged when ZDOTS_CAPTURE_ENABLED=1
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
