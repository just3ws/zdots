---
id: Z-152
title: 'Optional: o2 MCP server (4th) for on-demand runtime pull'
status: Done
assignee: []
created_date: '2026-06-15 01:57'
updated_date: '2026-06-30 00:27'
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
- [x] #1 o2 MCP server mirrors ctx-mcp registration + lifecycle
- [x] #2 Reads already-clean O2 data (single-source phi-patterns.yaml preserved)
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-06-29: bin/o2-mcp + bin/o2-mcp-register implemented. 6 tools: o2_errors, o2_slow, o2_failures, o2_service, o2_logs, o2_trace. Smoke-test passed (initialize + tools/list). Mirrors llama-mcp shape (hardcoded TOOLS, no Manifest dep). .mcp.json stanza needs explicit operator auth — same gate as Z-132. Stanza: { 'o2': { 'type': 'stdio', 'command': '${HOME}/.config/zsh/bin/o2-mcp', 'env': { 'ZDOTDIR': '${HOME}/.config/zsh' } } }. make check running.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
