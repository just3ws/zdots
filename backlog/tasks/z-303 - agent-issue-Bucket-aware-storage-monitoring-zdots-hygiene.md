---
id: Z-303
title: '[agent-issue] Bucket-aware storage monitoring & zdots-hygiene'
status: To Do
assignee: []
created_date: '2026-08-12 23:26'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 178895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `0fd86a80170421122ad67f4807d6003e`

Expand zdots storage monitoring beyond global df / probe to track specific context buckets (~/.local/share/llama-cpp, ~/.local/state/zdots/ingest-sources, ~/.colima, ~/.cache). Add bucket state output to capabilities --json, TTL expiration for ingest buffers & diagnostic logs, and a unified zdots-hygiene command for system storage sweeps.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01 review: `zdots-storage` now reports models, Colima, durable ingest,
tool caches, logs/OpenObserve, and backup buckets. `capabilities --json` now
embeds this inventory under `storage`; targeted JSON contract and storage
hygiene tests pass. `zdots-hygiene` previews age-based log/scratch and cache
cleanup, but durable ingest sources remain retained because they are source
media. No automatic ingest TTL or sweep was enabled. Keep this task open until
the operator-facing durable-source retention policy and warning thresholds
are explicitly resolved.
<!-- SECTION:NOTES:END -->
