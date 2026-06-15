---
id: Z-143
title: 'Bridge the Contextual Continuity Gap: Implement the ''Librarian'' Member'
status: Experimental
assignee: []
created_date: '2026-06-10 13:22'
updated_date: '2026-06-15 01:37'
labels:
  - zsynod
  - context
  - knowledge-layer
  - experimental
dependencies:
  - Z-142
priority: medium
ordinal: 34890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the 'Librarian' seat in zsynod for automated Knowledge Base injection.
  
  **Goal:** Provide AI agents with relevant Lessons Learnt and Methodologies during synod turns without manual hydration.
  
  **Requirements:**
  1. Create a wrapper for 'zdots-ctx' that can be invoked during 'zsynod tick'.
  2. Implement automated retrieval of relevant KB entries based on the task ID (Z-NNN).
  3. Inject retrieved context into the deliberation prompt for all participants.
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
