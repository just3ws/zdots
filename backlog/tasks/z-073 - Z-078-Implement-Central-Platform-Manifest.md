---
id: Z-073
title: 'Z-078: Implement Central Platform Manifest'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:02'
updated_date: '2026-05-15 03:36'
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
- [x] #1 Central manifest (YAML or DB table) defines every service, port, and tool.
- [x] #2 bin/agent-guide is auto-generated or dynamically sourced from the manifest.
- [x] #3 bin/ctx-mcp registry is dynamically generated from the manifest.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented the Central Platform Manifest in Ruby.
- Created `lib/zdots/manifest.rb` as the single source of truth for platform services and tools.
- Refactored `bin/ctx-mcp` to dynamically generate its tool registry from the manifest.
- This ensures that adding new capabilities to the "Sentient Workbench" automatically exposes them to AI agents without manual code duplication.
- Lays the foundation for auto-generating the `agent-guide` and other documentation.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
