---
id: Z-247
title: >-
  [agent-issue] Pipeline observability: per-job log files + structured,
  schema-validatable pipeline event log. Requi
status: To Do
assignee: []
created_date: '2026-07-21 17:07'
updated_date: '2026-07-21 17:20'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Direction (operator + agent, 2026-07-21): build #2 only — schema-validated JSONL event stream is primary; per-job 'log files' become a derived view (jq by job_id or a zdots-ctx jobs log <id> wrapper), not a storage layout. Design pins: (a) JSONL file, NOT a Postgres events table — the event log must survive DB/worker failure and append-only files have no interesting failure modes; rotate via existing log-rotate. (b) PHI-safe by construction: structural fields only (job_id, media_source_id, stage, event, ts, attempt, error_class enum, artifact paths) — no free-text content field, so nothing to scrub. Raw tool output stays in artifacts referenced by events. (c) Draft 7 schema in etc/ + contract test (validate-at-the-seam, same principle as Z-234). (d) OTel collector tails the JSONL — closes Z-229 with the same emit point.
<!-- SECTION:NOTES:END -->
