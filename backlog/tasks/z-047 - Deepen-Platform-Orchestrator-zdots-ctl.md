---
id: Z-047
title: Deepen Platform Orchestrator (zdots-ctl)
status: To Do
assignee: []
created_date: '2026-05-06 06:13'
labels: []
milestone: m-3
dependencies:
  - Z-043
  - Z-045
  - Z-046
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Complete the architectural deepening by making zdots-ctl a high-leverage orchestrator that operates entirely on abstract service interfaces.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Simplify bin/zdots-ctl to be a pure orchestrator of the lifecycle module.
- [ ] #2 Remove service-specific implementation details (e.g., direct launchctl calls) from zdots-ctl.
- [ ] #3 Ensure zdots-ctl check uses the new metadata service for tool and config validation.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
