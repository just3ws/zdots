---
id: Z-298
title: >-
  [agent-issue] redis crash-loops on startup: redis.conf loads
  modules/redisbloom/redisbloom.so which doesn't exist
status: To Do
assignee: []
created_date: '2026-08-08 18:25'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 173895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `60ae42c257383c0d1f1953df6ff769ca`

redis crash-loops on startup: redis.conf loads modules/redisbloom/redisbloom.so which doesn't exist at that path, causing 'server aborting' and immediate exit; launchd restarts it every ~10s (see /opt/homebrew/var/log/redis.log). zsvc reports state=scheduled (never reaches running), zdots-ctl status reports cache:false. Root cause is the module path/config, not the launch mechanism — needs redis.conf module line fixed or removed, or the module file provisioned.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
