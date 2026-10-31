---
id: Z-356
title: '[agent-issue] Remove retired LGTM host aliases from /etc/hosts'
status: To Do
assignee: []
created_date: '2026-10-31T23:19:00Z'
labels:
  - agent-reported
  - request
dependencies: []
priority: low
ordinal: 227895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** low
**Trace ID:** `5175011939a1195d366748987d19123f`

I audited `zdots-endpoints` after Z-134 retired the LGTM/Grafana stack. `/etc/hosts` still maps `grafana.local` and `lgtm.local` to 127.0.0.1. The endpoint inventory therefore lists both as NO VHOST and suggests adding nginx server blocks, which is misleading for retired names. Please remove these stale mappings through the privileged host-config path and confirm the route inventory no longer advertises them. This session did not modify /etc/hosts.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
