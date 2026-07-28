---
id: Z-246
title: >-
  [agent-issue] llama-mcp: llama_health reports 'unreachable at
  http://127.0.0.1:11500' while a direct curl of the s
status: Done
assignee: []
created_date: '2026-07-21 16:59'
updated_date: '2026-07-28 17:20'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 122895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `262025207aeb723c5f1b68236fc119cd`

llama-mcp: llama_health reports 'unreachable at http://127.0.0.1:11500' while a direct curl of the same /health returns 200 and zsvc shows llama-server running (PID 42124). Reproduced twice in one session (Claude Code MCP client). bin/llama-mcp tool_llama_health shells 'curl -sf -m 3 $AI_ENDPOINT/health' — suspect the MCP server subprocess env (ZDOTS_AI_ENDPOINT resolution or curl availability/sandboxing under the CC-spawned process) rather than the server. ctx MCP works in the same session, so it's llama-mcp-specific.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-07-28: root cause — run_cmd passed timeout: to Open3.capture3; unknown options forward to spawn → ArgumentError → blanket rescue → exit 1 for EVERY llama-mcp tool call. Fixed in commit 5770440 (Timeout.timeout wrapper). Verified via stdio tools/call: llama_health now reports reachable.
<!-- SECTION:NOTES:END -->
