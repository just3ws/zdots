---
id: Z-198
title: >-
  [agent-issue] zdots' own etc/nginx/servers/my.conf is stale vs the ~/my-owned
  source: still my.local-canonical wit
status: To Do
assignee: []
created_date: '2026-07-03 21:59'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 94890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `160b54f963f2498e1f715ff77df2388f`

zdots' own etc/nginx/servers/my.conf is stale vs the ~/my-owned source: still my.local-canonical with proxy_pass to /tmp/my_prod.sock, while ~/my/context-engine/ops/nginx/servers/my.conf (the real deploy source) has my.localhost-canonical + PORT 7010 for weeks. zdots.conf's my.conf header comment claims 'Deployed by bin/bootstrap alongside zdots.conf' — if bootstrap ever runs sync again on this machine it would clobber the live my.localhost config with the stale one. Surfaced during decision-011 (.localhost TLD migration). Recommend: either delete zdots' copy of my.conf (my owns its own deploy path via nginx-regen-certs' sync_configs, which already only touches tracked-managed files) or make it explicitly a stub/pointer, not a divergent live copy.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
