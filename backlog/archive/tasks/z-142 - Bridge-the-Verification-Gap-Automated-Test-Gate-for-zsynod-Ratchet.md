---
id: Z-142
title: 'Bridge the Verification Gap: Automated Test-Gate for zsynod Ratchet'
status: Experimental
assignee: []
created_date: '2026-06-10 13:22'
updated_date: '2026-06-15 01:37'
labels:
  - zsynod
  - ratchet
  - automation
  - experimental
dependencies: []
priority: high
ordinal: 33890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement automated verification for the zsynod exec-tick loop. 
  
  **Goal:** Ensure that every 'click' of the ratchet is validated by the platform's test suite before being finalized.
  
  **Requirements:**
  1. Enhance 'exec-tick' to accept a test reference (e.g. a .bats file).
  2. Implement an 'auto-verify' step in 'zsynod queue' that runs the test against the proposed patch.
  3. Automatically log test failures back to the synod ledger as 'speak' entries to inform the next deliberation turn.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Parked Experimental 2026-06-14: zsynod is contained under experiments/zsynod/ (commit c250f90) — a funded, held experiment for future analysis, not active backlog work. Backend/integration direction is settled (llama.cpp primary). Pick back up deliberately when zsynod is reactivated. See experiments/zsynod/, project_zsynod.
<!-- SECTION:NOTES:END -->
