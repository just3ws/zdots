---
id: Z-305
title: '[agent-issue] CI Check workflow failing on main: untrusted brew tap'
status: Done
assignee: []
created_date: '2026-08-20 13:53'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 180895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `2a3a527f1a190e996eb00c5404f3154e`

GitHub Actions 'Check' workflow on zdots main has failed on the last 3 pushes (since 2026-08-17T18:55:32Z, run 32057477609 onward, still failing as of HEAD 8dcf0035). Root cause from log: brew bundle refuses to load formula arimxyer/tap/models — 'Refusing to load formula arimxyer/tap/models from untrusted tap arimxyer/tap. Run brew trust --formula arimxyer/tap/models or brew trust arimxyer/tap to trust it.' brew bundle failed after 3 attempts, exit code 1. Needs a brew trust step (or dropping/pinning the tap) in the CI workflow or Brewfile. Secret-scan workflow on the same commits is green.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed 2026-08-22 in commit 3c9eb99d. Removed `tap "arimxyer/tap"` and
`brew "arimxyer/tap/models"` from Brewfile.common rather than adding a `brew trust`
step: nothing in zdots references the formula, so trusting an unaudited third-party
tap on a PHI-adjacent machine to install an unused binary was the wrong trade. The
already-installed local binary is untouched — if it is wanted interactively it can
be reinstalled explicitly.

Note the ticket understated the age: Check has been red since at least 2026-08-10
(5 consecutive failures), not 2026-08-17.
<!-- SECTION:NOTES:END -->
