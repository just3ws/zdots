---
id: Z-121
title: Audit architecture diagrams across Mermaid types
status: Done
assignee: []
created_date: '2026-05-31 15:50'
updated_date: '2026-06-16 01:26'
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
- [ ] #4 All 3 broken diagrams pass mmdc with exit 0: docs/architecture.md (subgraph Host label with unquoted parens/spaces ~L114), docs/local-ai.md (quadrantChart label with unquoted parens), docs/repository-evolution.md (xyChart-beta wrong casing -> xychart-beta)
- [ ] #5 erDiagram in docs/architecture.md reflects current schema: embedding is vector(768) not 3584; PHI columns are *_enc bytea (content_enc, session_residue summary/intent/result); shell_hook_metrics table present
- [ ] #6 Stale topology references corrected: README.md empty Colima group + openobserve-ctl->docker-compose edge (false post-Z-134, now native launchd); docs/lifecycle.md adds OpenObserve to zsvc registry; docs/platform-dependency-graph.md whisper-ctl->zsvc edge removed or scoped (whisper-ctl not registered in bin/zsvc)
- [ ] #7 Every Mermaid diagram in the repo machine-validates via mmdc in CI or a make target (regression guard so diagram drift fails loudly, not silently)
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
