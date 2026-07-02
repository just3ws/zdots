---
id: Z-184
title: >-
  [agent-issue] Publish a versioned service surface for external tenants
  ([redacted] is first consumer)
status: To Do
assignee: []
created_date: '2026-06-30 23:28'
labels:
  - agent-reported
  - request
dependencies: []
priority: high
ordinal: 80890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** high
**Trace ID:** `5b4468133af32eac3c5e4c0e472302a1`

Evaluating how the [redacted] work polyrepo (~/github.com/[redacted], the bear-* platform) consumes zdots. Finding: [redacted] is zdots' first external tenant — it consumes ai-query (inference 11500), zdots-ctx (Knowledge Layer), zdots-gh (DuckDB warehouse), zdots O2, and the whisper transcription pipeline — but discovers them only by their presence on PATH and scrapes stderr/returncode to learn state. work-infer hard-fails with a generic 'install zdots' when ai-query is absent; it cannot tell mode=none from server-down.

Request: have capabilities --json publish a stable, versioned service surface — for each Platform Service the endpoint, model/mode, and readiness (inference 11500, llama-embed 11501, O2, zdots-ctx, zdots-gh warehouse). Foreign consumers (work-capabilities, work-infer) then validate/discover against one schema instead of probing PATH and degrade gracefully with a real reason. This is the anchor for a small kaizen set (embeddings unification, zdots-ctx --json envelope, zdots-gh warehouse-path resolver, zdots-otel enroll, shared CLI-plumbing lib) — goal: let bear-* focus entirely on [redacted] domain concerns while zdots owns the platform seam. No change to [redacted] required; this is zdots-side service-surface work.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
