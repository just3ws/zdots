---
id: Z-073
title: 'Z-078: Implement Central Platform Manifest'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:02'
labels:
  - industrialization
  - discovery
  - architecture
dependencies:
  - Z-072
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a single-source-of-truth manifest for the platform. This allows all discovery tools (Agent Guide, Capabilities, MCP) to stay perfectly in sync, reducing the maintenance overhead as the platform grows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Central manifest (YAML or DB table) defines every service, port, and tool.
- [ ] #2 bin/agent-guide is auto-generated or dynamically sourced from the manifest.
- [ ] #3 bin/ctx-mcp registry is dynamically generated from the manifest.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
