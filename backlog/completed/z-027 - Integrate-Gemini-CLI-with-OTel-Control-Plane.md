---
id: Z-027
title: Integrate Gemini CLI with OTel Control Plane
status: Done
assignee: []
created_date: '2026-03-28 17:23'
updated_date: '2026-06-29 19:15'
labels:
  - wave2
milestone: m-2
dependencies:
  - Z-134
modified_files:
  - bin/gemini-invoke
  - tests/gemini_invoke.bats
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Gemini CLI to bridge its internal OTLP spans into the Zdots observability graph, enabling end-to-end tracing of agent-driven modifications.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Implement Gemini discovery logic for ZDOTS_TRACE_ID
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
OTEL_RESOURCE_ATTRIBUTES exported in gemini-invoke with append semantics (${existing:+existing,}zdots.trace.id=${ZDOTS_TRACE_ID}). Three contract tests cover: TRACEPARENT carries trace ID, OTEL_RESOURCE_ATTRIBUTES set when unset, OTEL_RESOURCE_ATTRIBUTES appends when pre-existing. Tests pass 3/3. End-to-end verification (gemini_cli_* metrics carrying zdots_trace_id in O2) deferred — requires a live Gemini session; mechanism confirmed via claude_code_* metrics schema which uses the same OTEL SDK flatten pattern (dots→underscores in O2 columns).
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
