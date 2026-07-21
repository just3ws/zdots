---
id: Z-247
title: >-
  [agent-issue] Pipeline observability: per-job log files + structured,
  schema-validatable pipeline event log. Requi
status: To Do
assignee: []
created_date: '2026-07-21 17:07'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 123895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `262025207aeb723c5f1b68236fc119cd`

Pipeline observability: per-job log files + structured, schema-validatable pipeline event log. Requirements from operator (2026-07-21): (1) each worker job should write its own log file (e.g. ~/.local/state/zdots/jobs/<job-id>.log) instead of only interleaving into zdots-worker.log; (2) the ingest pipeline should emit a structured event log (JSONL: job_id, media_source_id, stage, event, ts, attempt, error_class) validated against a JSON Schema (Draft 7) shipped in etc/, so pipeline behavior can be validated mechanically. Related: Z-229 (worker failures invisible to o2 — the JSONL doubles as an OTel source), Z-234 (timeline stage emits unvalidated LLM prose — same validate-at-the-seam principle), Z-228/Z-242/Z-243 (retry-loop diagnosis needs per-job history).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
