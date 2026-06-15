---
id: Z-045
title: Refactor Colima/LGTM Lifecycle
status: To Do
assignee: []
created_date: '2026-05-06 06:12'
updated_date: '2026-06-15 01:38'
labels:
  - wave2
milestone: m-3
dependencies:
  - Z-134
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate the complex Docker/Colima lifecycle into the standard platform engine, ensuring consistency across all service types.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Refactor bin/local-ci to use lib/lifecycle.bash for start/stop/status.
- [ ] #2 Implement a Docker/Compose adapter for the lifecycle engine.
- [ ] #3 Maintain support for 'prune' and 'rebuild' as service-specific extensions.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reconcile 2026-06-14: the LGTM half of this task is OBSOLETE — Z-134 retired LGTM for OpenObserve (LGTM compose archived to etc/archive/, local-ci deprecated). Re-scope to Colima-lifecycle only, or fold into Z-047 (Deepen Orchestrator). See decision/doc-003 divergence flag #1.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
