---
id: Z-226
title: '[agent-issue] ssh k8s tunnel binds forwards on all interfaces (LAN-reachable)'
status: To Do
assignee: []
created_date: '2026-07-15 17:56'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 105895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

Found during /cc-audit listener sweep, not a task blocker. lsof shows ssh pid 62818 binding forwards on all interfaces (*:30080, *:30035, *:10250, *:57448) alongside loopback-only ones. Kubelet port 10250 and NodePorts are LAN-reachable on this PHI machine; §10 posture expects loopback-only. If not deliberate, drop -g / 0.0.0.0 bind addresses from the forward spec (bind 127.0.0.1 explicitly).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
