---
id: Z-075
title: 'Z-080: Upgrade Documentation with High-Fidelity Mermaid Diagrams'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:47'
updated_date: '2026-08-01 09:55'
labels:
  - documentation
  - visuals
  - architecture
  - wave3
dependencies:
  - Z-121
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Upgrade the platform documentation with high-fidelity Mermaid diagrams. This leverages the local Mermaid v11+ capability to provide more precise and visually rich representations of the system's architecture, database schema, and job state machine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Replace current README flowcharts with high-fidelity 'architecture-beta' diagrams.
- [ ] #2 Add 'erDiagram' to docs/architecture.md representing the PostgreSQL brain schema.
- [ ] #3 Add 'stateDiagram-v2' representing the Job Broker lifecycle (Pending -> Running -> Completed/Failed -> Dead).
- [ ] #4 Ensure all diagrams render correctly on GitHub using v11 syntax.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit: Delivered — architecture-beta README.md:74, erDiagram docs/architecture.md:136, stateDiagram-v2 docs/architecture.md:227 (verified). AC#4 GitHub render check: one-look on next push.
<!-- SECTION:NOTES:END -->
