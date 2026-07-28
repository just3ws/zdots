---
id: Z-196
title: >-
  [agent-issue] adots capabilities.sh uses 'declare -a' (no -g) for
  ADOTS_ALL_CAPABILITIES and category arrays — whe
status: Done
assignee: []
created_date: '2026-07-02 19:28'
updated_date: '2026-07-28 19:08'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 92890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `160b54f963f2498e1f715ff77df2388f`

adots capabilities.sh uses 'declare -a' (no -g) for ADOTS_ALL_CAPABILITIES and category arrays — when sourced inside a function (lib/peer-bootstrap.bash, any function-scoped consumer) bash and zsh make the arrays function-local and they evaporate on return. zdots' etc/capabilities.sh uses 'declare -ga' and survives. Fix: -a → -ga in ~/.config/adots/capabilities.sh. Workaround shipped zdots-side: consumers read exported scalar counts (ZDOTS/ADOTS_PEER_CAPS) instead of raw arrays.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed in adots d98b357: declare -a → declare -ga at capabilities.sh:172. Category arrays use bare assignment (already global). Verified ADOTS_ALL_CAPABILITIES survives function-scoped sourcing: 32/32 in bash and zsh. Peer attestation should now report 32/32.
<!-- SECTION:NOTES:END -->
