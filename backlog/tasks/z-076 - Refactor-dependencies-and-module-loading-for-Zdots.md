---
id: Z-076
title: Refactor dependencies and module loading for Zdots
status: To Do
assignee: []
created_date: '2026-05-15 06:22'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current codebase contains several uncommitted changes aimed at cleaning up dependencies (OTEL) and adjusting module loading patterns (removing require_relative). This task tracks the formalization and completion of these improvements to ensure they are consistent and production-ready.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Remove unnecessary OTEL and require_relative dependencies as identified in the current diff.
- [ ] #2 Ensure application stability after changes.
- [ ] #3 Verify that the database configuration path is correctly updated to .env.shared.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
