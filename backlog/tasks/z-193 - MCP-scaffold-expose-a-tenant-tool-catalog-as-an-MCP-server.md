---
id: Z-193
title: 'MCP scaffold: expose a tenant tool catalog as an MCP server'
status: To Do
assignee: []
created_date: '2026-07-01 23:21'
labels:
  - feature
  - platform-service
dependencies: []
priority: low
ordinal: 89890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bear-mcp (14K python) hand-rolls an MCP server exposing the emrbear analysis toolchain. zdots already ships ctx/llama/o2 MCP servers; the generic piece is the scaffold — given a tool catalog (bin/ namespace + help contracts), serve it over MCP stdio. Tenant supplies the tool list/allowlist; zdots owns server plumbing, schema derivation from --help, and safety (read-only default, allowlist gating). Lowest priority of the consolidation set; design against Z-184's service surface.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Generic MCP server takes a catalog/allowlist and exposes tools over stdio
- [ ] #2 Schemas derived from the help-from-header contract; write-class gating honored
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
