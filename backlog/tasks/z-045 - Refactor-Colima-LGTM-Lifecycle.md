---
id: Z-045
title: Refactor Colima/LGTM Lifecycle
status: To Do
assignee: []
created_date: '2026-05-06 06:12'
updated_date: '2026-06-15 02:04'
labels:
  - wave2
milestone: m-3
dependencies:
  - Z-047
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate the complex Docker/Colima lifecycle into the standard platform engine, ensuring consistency across all service types.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Implement a Docker/Compose adapter for the lifecycle engine.
- [ ] #2 Maintain support for 'prune' and 'rebuild' as service-specific extensions.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Divergence resolved (doc-003 flag #1): Z-134 retired the LGTM stack, so the bin/local-ci refactor AC is obsolete and removed. Remaining live value = the generic Docker/Compose lifecycle adapter for Colima-managed services, which belongs under Z-047 (Deepen Orchestrator). Re-scoped to that; now depends on Z-047. No dead LGTM scope remains.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
