---
id: Z-143
title: 'Bridge the Contextual Continuity Gap: Implement the ''Librarian'' Member'
status: To Do
assignee: []
created_date: '2026-06-10 13:22'
updated_date: '2026-06-14 18:35'
labels:
  - zsynod
  - context
  - knowledge-layer
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
