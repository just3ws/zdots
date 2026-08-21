---
id: Z-226
title: '[agent-issue] ssh k8s tunnel binds forwards on all interfaces (LAN-reachable)'
status: Done
assignee: []
created_date: '2026-07-15 17:56'
updated_date: '2026-08-20 19:19'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mitigated 2026-08-20: loaded pf anchor zdots.z226 blocking inbound TCP:10250 on non-loopback interfaces (block in quick on ! lo0 proto tcp from any to any port 10250). Loopback access confirmed still working (curl 127.0.0.1:10250 -> 401 Unauthorized, same as before). Root cause (colima ssh port-forwarder mirrors k3s kubelet's 0.0.0.0 bind from guest) is upstream colima/k3s behavior, not a zdots config fix — this pf rule is host-level compensating control. Rule does not persist across reboot; anchor is ephemeral (loaded via pfctl -f, not via /etc/pf.conf) — will need reapplying after restart until made durable.
<!-- SECTION:NOTES:END -->
