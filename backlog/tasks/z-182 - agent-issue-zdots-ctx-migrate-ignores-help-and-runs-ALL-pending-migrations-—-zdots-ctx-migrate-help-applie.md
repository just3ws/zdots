---
id: Z-182
title: >-
  [agent-issue] zdots-ctx migrate ignores --help and runs ALL pending migrations
  — 'zdots-ctx migrate --help' applie
status: Done
assignee: []
created_date: '2026-06-30 12:14'
updated_date: '2026-07-28 17:20'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 78890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `5a34494e2b29252e0fe90e44150a466e`

zdots-ctx migrate ignores --help and runs ALL pending migrations — 'zdots-ctx migrate --help' applied a PHI-encryption migration that was meant to be held. Fix: honor --help (print usage, don't migrate) and add --to <version> for targeted single-migration apply.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-07-28: verified fixed on this machine — cmd_migrate short-circuits via zdots_cli_wants_help before the migrator (bin/zdots-ctx:219-227); 'zdots-ctx migrate --help' prints usage, exit 0, no migrations applied. Unknown flags are rejected. (--to <version> targeted apply was not implemented; file separately if still wanted.)
<!-- SECTION:NOTES:END -->
