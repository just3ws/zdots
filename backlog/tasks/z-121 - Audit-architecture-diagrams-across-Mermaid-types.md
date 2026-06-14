---
id: Z-121
title: Audit architecture diagrams across Mermaid types
status: To Do
assignee: []
created_date: '2026-05-31 15:50'
updated_date: '2026-06-14 18:37'
labels:
  - agent-ready
  - wave4
dependencies: []
documentation:
  - docs/architecture-diagram-audit-plan.md
  - docs/repository-evolution.md
modified_files:
  - docs/architecture-diagram-audit-plan.md
  - docs/repository-evolution.md
priority: medium
ordinal: 12890
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every Mermaid type in docs/architecture-diagram-audit-plan.md is marked used, translated, or not useful
- [ ] #2 Every major zdots subsystem has at least one diagram linked to source files and validation tests
- [ ] #3 GitHub PR rendering is checked for every added Mermaid block
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Use docs/architecture-diagram-audit-plan.md as the implementation plan. Inventory current Mermaid blocks, map source files to useful diagram types, add diagrams in docs/platform-service-plane.md, docs/architecture.md, docs/local-ai.md, docs/backlog.md, docs/testing.md, and docs/wiki/System-Map.md, then verify docs-contract and GitHub rendering.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added docs/repository-evolution.md with Git-derived timeline, monthly commit velocity histogram/table, annual histogram, subject-mix pie chart, current PR gitGraph, diagram priority quadrant, and rollout gantt.

Preserved both the original architecture audit plan and the new repository evolution page as tracked docs for Z-121.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
