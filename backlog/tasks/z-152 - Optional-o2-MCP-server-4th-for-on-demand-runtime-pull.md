---
id: Z-152
title: 'Optional: o2 MCP server (4th) for on-demand runtime pull'
status: To Do
assignee: []
created_date: '2026-06-15 01:57'
labels:
  - wave3
  - observability
dependencies:
  - Z-135
ordinal: 43890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Optional 4th MCP server mirroring the ctx MCP pattern for on-demand O2 runtime pull. Descoped from Z-135 (which landed P1+P2+P4); zdots-o2-query already covers CLI on-demand pull, so this is a convenience enhancement, not a requirement. See Z-135.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 o2 MCP server mirrors ctx-mcp registration + lifecycle
- [ ] #2 Reads already-clean O2 data (single-source phi-patterns.yaml preserved)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
