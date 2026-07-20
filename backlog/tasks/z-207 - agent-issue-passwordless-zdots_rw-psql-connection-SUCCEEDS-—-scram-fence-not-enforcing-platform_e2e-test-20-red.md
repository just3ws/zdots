---
id: Z-207
title: >-
  [agent-issue] passwordless zdots_rw psql connection SUCCEEDS — scram fence not
  enforcing (platform_e2e test 20 red
status: Done
assignee: []
created_date: '2026-07-11 16:09'
updated_date: '2026-07-15 13:55'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 102895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `7d561ced257d57f261bf6fed40dc4959`

passwordless zdots_rw psql connection SUCCEEDS — scram fence not enforcing (platform_e2e test 20 red)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: postgresql@18 migration shipped a stock all-trust pg_hba.conf — the documented scram fence (docs/architecture.md §7) was never installed on the new datadir, and zdots_ro/zdots_rw had NULL passwords with no Keychain keys.

Fix (machine state, in documented order):
1. zdots-ctx rotate-creds --all → passwords set + stored in Keychain
2. Fence lines (local/host 127.0.0.1/::1 scram-sha-256 for zdots_ro,zdots_rw) inserted ABOVE the catch-all trust rules; timestamped pg_hba.conf.bak alongside
3. pg_reload_conf

Verified: passwordless zdots_rw REJECTED (e2e test 20 green), Keychain-key auth works (test 21 green), OS-user trust intact, zdots-ctx status connects, worker restarted and processing through the fence, context-engine 200.

Repo change: platform_e2e ruby tests now derive the expected version from etc/ruby-version instead of a hardcoded 4.0.5 (broke on tonight's 4.0.6 bump).
<!-- SECTION:NOTES:END -->
