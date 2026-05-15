---
id: Z-076
title: Refactor dependencies and module loading for Zdots
status: Done
assignee: []
created_date: '2026-05-15 06:22'
updated_date: '2026-05-15 06:26'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current codebase contains several uncommitted changes aimed at cleaning up dependencies (OTEL) and adjusting module loading patterns (removing require_relative). This task tracks the formalization and completion of these improvements to ensure they are consistent and production-ready.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Remove unnecessary OTEL and require_relative dependencies as identified in the current diff.
- [x] #2 Ensure application stability after changes.
- [x] #3 Verify that the database configuration path is correctly updated to .env.shared.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Completed refactoring of dependencies and module loading:
- Removed unnecessary OpenTelemetry SDK dependencies.
- Replaced `require_relative` calls with cleaner module loading patterns.
- Updated database configuration to load from `../../.env.shared`.
- Verified stability with `make check` (160/160 tests passed).
- Committed changes as `a6099f0`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
