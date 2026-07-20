---
id: Z-234
title: >-
  [agent-issue] ingest timeline stage writes non-JSON LLM prose to
  timeline.json; zdots-publish then fails the whole
status: To Do
assignee: []
created_date: '2026-07-16 01:01'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 113895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `233e438f1a0e17373e3407b85d1735df`

ingest timeline stage writes non-JSON LLM prose to timeline.json; zdots-publish then fails the whole ingest — validate/parse timeline output before writing (observed: haiku replied "I'm..." on a 19s video with no extractable moments; published stage retry-looped on parse error)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
