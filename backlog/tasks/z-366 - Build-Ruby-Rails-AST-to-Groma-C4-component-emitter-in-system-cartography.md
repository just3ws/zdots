---
id: Z-366
title: Build Ruby/Rails AST-to-Groma C4 component emitter in system-cartography
status: To Do
assignee: []
created_date: '2026-11-14T22:48:00Z'
labels:
  - architecture
  - groma
  - ruby
dependencies: []
priority: high
ordinal: 243895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend system-cartography with a Ruby script that introspects Rails/Sequel routes, controllers, jobs, and models and emits C4 component entries into groma/architecture.json so groma scan and Backlog.md work overlays have full component visibility across the Rails fleet.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Ruby/Rails introspector emits valid C4 component entries into groma/architecture.json
- [ ] #2 Idempotent merge with existing groma scan output
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
