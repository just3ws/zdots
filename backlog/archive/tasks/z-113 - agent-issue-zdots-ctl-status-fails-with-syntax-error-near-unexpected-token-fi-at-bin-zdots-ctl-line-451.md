---
id: Z-113
title: >-
  [agent-issue] zdots-ctl status fails with syntax error near unexpected token
  fi at bin/zdots-ctl line 451
status: Done
assignee: []
created_date: '2026-05-28 13:35'
labels:
  - agent-reported
  - bug
dependencies: []
priority: medium
ordinal: 4890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `070b160f5b695e1b401d690d64375c6a`

zdots-ctl status fails with syntax error near unexpected token fi at bin/zdots-ctl line 451

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Resolution

<!-- SECTION:RESOLUTION:BEGIN -->
Removed the stray `fi` in `bin/zdots-ctl` local proxy diagnostics and verified `zsh -n bin/zdots-ctl`.
<!-- SECTION:RESOLUTION:END -->
