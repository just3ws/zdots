---
id: Z-239
title: >-
  [agent-issue] tests/platform_e2e.bats:165 'methodologies present by slug'
  asserts 4 hardcoded seed slugs (zsh-no-r
status: To Do
assignee: []
created_date: '2026-07-21 13:29'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 118895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `2f902b70738550f801577f176ee86c12`

tests/platform_e2e.bats:165 'methodologies present by slug' asserts 4 hardcoded seed slugs (zsh-no-reserved-vars, ruby-declare-runtime-gems, tools-zsvc-service-control, docs-gap-register) that no longer exist — brain now holds 108 methodologies, none matching. Stale fixture: update the expected slugs or assert count>0. Only failing test in the e2e suite (33/34).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
