---
id: Z-045
title: Refactor Colima Lifecycle Integration
status: To Do
assignee: []
created_date: 2026-05-06 06:12
updated_date: '2026-10-31T21:25:00Z'
labels:
  - wave2
milestone: m-3
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a Docker/Compose lifecycle adapter for Colima-managed services. Preserve service-specific prune and rebuild operations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Implement a Docker/Compose adapter for the lifecycle engine.
- [ ] #2 Maintain support for 'prune' and 'rebuild' as service-specific extensions.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope: implement the generic Docker/Compose lifecycle adapter for Colima-managed services; retain service-specific prune/rebuild extensions. Z-047 depends on this task, so complete the adapter before simplifying zdots-ctl. Z-134 retired LGTM; its former LGTM-specific scope is out of scope.
<!-- SECTION:NOTES:END -->
