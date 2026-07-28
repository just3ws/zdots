---
id: Z-178
title: '[agent-issue] Wire cc-burn --assert-ceiling gate into cl alias (adots)'
status: Done
assignee: []
created_date: '2026-06-29 03:08'
updated_date: '2026-07-28 19:11'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 74890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `0d2e75b812e72d620a684e07675a75c9`

Wire cc-burn --assert-ceiling gate into cl alias (adots)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wired in zdots a1eae3f: cl is now a function in aliases.bash gating launch via cc-burn --assert-ceiling — alert (exit 2) blocks with ZDOTS_CC_ALLOW_OVERRUN override hint, warn (1) prints and proceeds, monitor unavailable (3) proceeds. Note: task said adots, but cl was never defined there — it lives in zdots aliases.bash:100.
<!-- SECTION:NOTES:END -->
