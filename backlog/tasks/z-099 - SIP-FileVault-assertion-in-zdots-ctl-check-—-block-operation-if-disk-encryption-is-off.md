---
id: Z-099
title: >-
  SIP + FileVault assertion in zdots-ctl check — block operation if disk
  encryption is off
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
  - bin/zdots-ctl
  - lib/phi_assertions.bash
priority: high
ordinal: 840
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
FileVault is the disk-level protection layer for PHI. SIP prevents tampering with system binaries that zdots depends on (including `/usr/bin/log` for audit). Without asserting both are enabled, `zdots-ctl check` gives a false clean bill of health.

On a work machine, `zdots-ctl check` should fail — not warn — if FileVault is off. SIP off should be a loud warning (it can be legitimately off on a dev machine).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `zdots-ctl check` runs `fdesetup status` and reports FileVault state; exits non-zero if ZDOTS_WORK_MACHINE=1 and FileVault is off
- [ ] #2 `zdots-ctl check` runs `csrutil status` and reports SIP state; warns (does not block) if SIP is disabled
- [ ] #3 Both checks are grouped under a PHI section in check output, distinct from service health
- [ ] #4 Assertions are macOS-only — non-darwin platforms skip with a note
- [ ] #5 Output is machine-readable: each check emits a structured line parseable by future scripts (PASS/WARN/FAIL prefix)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
