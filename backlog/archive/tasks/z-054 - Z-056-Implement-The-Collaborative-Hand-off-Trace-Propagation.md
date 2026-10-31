---
id: Z-054
title: 'Z-056: Implement "The Collaborative Hand-off" (Trace Propagation)'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-12 19:07'
updated_date: '2026-05-15 02:03'
labels:
  - sentient-workbench
  - otel
  - ai
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Propagate W3C Trace IDs from the shell session to all AI subagent invocations. This creates a unified causal chain of work, allowing you to see exactly which shell intent led to which agent actions in your observability dashboard.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 bin/gemini-invoke (and other agent bridges) accepts and propagates ZDOTS_TRACE_ID.
- [x] #2 Subagent operations (replacements, shell commands) are tagged with the parent Trace ID in OTel.
- [x] #3 Grafana Tempo shows a unified trace view combining human shell commands and agent tool calls.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented "The Collaborative Hand-off" (Trace Propagation).
- Created `bin/gemini-invoke` as a standardized, observable entry point for agent sessions.
- Injected `TRACEPARENT` and `ZDOTS_SPAN_ID` into agent environments, ensuring subagent actions are correctly linked to shell intent.
- Updated `aliases.bash` and `aliases.zsh` to use the observable wrapper.
- Verified span emission in OTel trace logs.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
