---
id: Z-306
title: >-
  [agent-issue] Versioned job-leads bus contract for wwworkremote/just3ws
  (companion to Z-184)
status: To Do
assignee: []
created_date: '2026-08-20 14:10'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 181895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `2a3a527f1a190e996eb00c5404f3154e`

Z-184 (versioned service surface for external tenants) is scoped only to the 'work' tenant's CLI-plumbing/service-discovery pain. It does not cover the 'job-leads' zdots-ctx message bus channel, which wwworkremote/core and just3ws.github.io both use for cross-agent job-lead coordination (see docs/cross-repo-interop.md — wwworkremote confirmed live sender via bus traffic 2026-08-17; just3ws documented on their side, not yet independently confirmed as sender). Today that bus has no versioned schema and no delivery guarantee documented on zdots' side — consumers poll and hope. Request: extend the Z-184 service-surface pattern to job-leads — a versioned message schema + delivery ack/read-receipt semantics for zdots-ctx bus-channels, so wwworkremote/just3ws can validate against a stable contract instead of guessing at bus state the way work-infer guessed at ai-query presence before Z-184. Related: Z-184, Z-254 (push-not-poll Turbo Streams, currently scoped to my's dashboard only — same underlying push-vs-poll gap).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
