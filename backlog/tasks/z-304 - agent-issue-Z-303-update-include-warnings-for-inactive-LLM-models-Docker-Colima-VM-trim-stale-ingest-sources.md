---
id: Z-304
title: >-
  [agent-issue] Z-303 update: include warnings for inactive LLM models,
  Docker/Colima VM trim, stale ingest sources
status: To Do
assignee: []
created_date: '2026-08-12 23:30'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 179895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `0fd86a80170421122ad67f4807d6003e`

Z-303 update: include warnings for inactive LLM models, Docker/Colima VM trim, stale ingest sources (>7d), package caches (uv/pnpm/brew), and diagnostic dumps (>14d).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01 review: `zdots-storage` reports inactive GGUF models, Colima
footprint, ingest sources older than seven days, package caches, and stale
diagnostic logs. `zdots-hygiene` reports cleanup candidates without applying
them by default. Current live report has 195 durable ingest files older than
seven days (464.9 MB), explicitly retained; no age-based source deletion was
run. Keep this task open: review signals exist, but the issue's requested
warning semantics and safe durable-source retention rule need a clear
acceptance decision.
<!-- SECTION:NOTES:END -->
