---
id: Z-055
title: 'Z-057: Implement "Predictive Pre-fetching" (Task Hydration)'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:07'
updated_date: '2026-05-15 02:03'
labels:
  - sentient-workbench
  - automation
  - dx
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Automatically adjust the shell environment (services, themes, and AI context) based on the active task in Backlog.md. The environment should "morph" to support the current engineering intent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Changing a task status to 'In Progress' in Backlog.md triggers a 'hydration' event.
- [x] #2 Hydration triggers service starts (e.g., Colima/AI) and theme shifts based on task labels.
- [x] #3 Relevant documentation for the task is pre-loaded into local AI context/VRAM.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented "Predictive Pre-fetching" (Task Hydration).
- Created `bin/ztask` to bridge the backlog with the live shell environment.
- `ztask start <id>` automatically marks tasks in-progress, starts platform services, and semantically hydrates the AI context using task-specific tags.
- Integrated `ztask` with the P10K prompt to track active task state.
- Verified end-to-end task activation and context hydration flow.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
