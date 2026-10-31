---
id: Z-144
title: 'Bridge the Physical Machine Gap: zsynod Cross-Platform Sync'
status: Experimental
assignee: []
created_date: '2026-06-10 13:22'
updated_date: '2026-06-15 01:37'
labels:
  - zsynod
  - sync
  - multi-platform
  - experimental
dependencies:
  - Z-142
priority: medium
ordinal: 35890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a 'zsynod sync-remote' utility to bridge forum state across machines.
  
  **Goal:** Seamlessly continue deliberations between personal and work machines using git as the transport layer.
  
  **Requirements:**
  1. Create 'zsynod sync-remote' to automate the pull -> verify -> status loop.
  2. Ensure strict adherence to the PHI boundary (§0.1.1) during work-machine syncs.
  3. Implement a 'resume-summary' that highlights what was decided on the other machine since the last local turn.
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
