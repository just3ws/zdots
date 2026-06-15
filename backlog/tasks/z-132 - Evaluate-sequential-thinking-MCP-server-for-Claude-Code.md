---
id: Z-132
title: Evaluate sequential-thinking MCP server for Claude Code
status: To Do
assignee: []
created_date: '2026-06-06 00:10'
updated_date: '2026-06-15 10:47'
labels:
  - ai-tooling
  - mcp
  - agent-ready
  - wave4
dependencies: []
priority: low
ordinal: 23890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Considered during the Claude Code + Pi/Aider integration (see ROUTER.md). A local-only reasoning scaffold that forces discrete, logged thinking steps before code — no data egress. One of only two pasted recommendations that passed vetting (the other is promptfoo); Kin/firelock.ai and fetch MCP were rejected as unverifiable / boundary-violating.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Confirm the server is the official @modelcontextprotocol/server-sequential-thinking (reject any unvetted/third-party source)
- [ ] #2 Verify it makes no network calls (safe on a PHI-adjacent machine)
- [ ] #3 If adopted, add to tracked .mcp.json and document in CLAUDE.md MCP section
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EVAL COMPLETE (sonnet, 2026-06-15) — awaiting operator adopt decision. (1) Provenance PASS: @modelcontextprotocol/server-sequential-thinking@2025.12.18, official Anthropic-maintained monorepo (github.com/modelcontextprotocol/servers), MIT, all maintainers @anthropic.com/@modelcontextprotocol.io — no fork. (2) Network PASS: 14.6kB/4 files; deps SDK(stdio)+chalk+yargs+zod, all in-process; grep of fetch/http/net/socket/dns/axios/got over dist/ = NONE; StdioServerTransport is stdin/stdout only, in-memory thoughtHistory, no egress/telemetry. (3) Proposed .mcp.json stanza (NOT applied): prefer pinned global install (npm i -g ...@2025.12.18) + command 'mcp-server-sequential-thinking' over 'npx -y' to avoid per-coldstart npm fetch on this PHI-adjacent box. (4) RECOMMEND ADOPT. Operator owns the .mcp.json + CLAUDE.md change (shared config, coordination).
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
