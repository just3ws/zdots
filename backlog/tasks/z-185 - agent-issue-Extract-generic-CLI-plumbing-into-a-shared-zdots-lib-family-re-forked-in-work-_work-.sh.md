---
id: Z-185
title: >-
  [agent-issue] Extract generic CLI plumbing into a shared zdots lib family
  (re-forked in [redacted] _bear-*.sh)
status: To Do
assignee: []
created_date: '2026-06-30 23:28'
labels:
  - agent-reported
  - request
dependencies: []
priority: high
ordinal: 81890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** high
**Trace ID:** `5b4468133af32eac3c5e4c0e472302a1`

Part of Z-184 (external-tenant service surface). The [redacted] bear-* platform re-forks generic CLI plumbing that should live at the core (zdots) layer, not in a consumer. Each fork is a place a downstream tenant carries logic — and bugs — that zdots already owns:

1. _work-audit.sh — command-audit NDJSON shim (write-class taxonomy read-only/lake-write/db-mutating, START/END/INVOKE records, chained EXIT trap). Duplicates zdots command-observability. Should be a sourceable zdots lib (e.g. lib/zdots/cli-audit.bash) any tool can source.

2. _work-help.sh bear_help — prints the header comment block for -h/--help before side effects. This is exactly the Z-182/Z-183 contract zdots just built. Should be a sourceable zdots lib so the help-from-header + honor-flags-before-destructive-side-effects contract is defined once.

3. _bear_resolve_docker_host (inside _work-help.sh) — hardcodes the LEGACY socket ~/.colima/default/docker.sock. zdots already fixed this drift with 'colima-status socket' and the socket moved to ~/.config/colima. The bear fork reintroduces the exact bug zdots eliminated. A shared lib that surfaces socket resolution removes the fork.

4. _work-man-gen — generates troff man pages from --help headers. Generic; duplicates man-from-header generation.

Request: expose these four as a small zdots lib family (sourceable .bash helpers + the man generator) so foreign tenants consume one implementation and inherit fixes. Goal: bear-* keeps only [redacted] domain logic; all CLI scaffolding is core-layer.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
