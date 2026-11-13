---
id: Z-364
title: >-
  [agent-issue] make check fails on the managed work Mac (2026-11-13, main
  462ce4f5) independent of any change: (1)
status: Done
assignee: []
created_date: '2026-11-13T17:54:00Z'
updated_date: '2026-11-13T19:22:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 241895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7a084f400fe91d285e4b113951e052c5`

make check fails on the managed work Mac (2026-11-13, main 462ce4f5) independent of any change: (1) 'expected exactly one PNPM_HOME/bin PATH entry' because ~/.local/share/pnpm/bin did not exist (bin/bootstrap is skipped on managed machines; created by hand); (2) bats failures in adots_my_structure (prepare/migrate), bus_schedule (passengers, conversations), utilization_analytics, and docs_contract #3/#13 (zdots-endpoints --help rc=1). docs_contract fails identically on main.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed forward on operator instruction (2026-11-13). make check on the managed Mac: 888 ok, 0 failed, 60 skipped with stated reasons.
Code fixes:
- zdots-endpoints: --help no longer dies under pipefail when nginx serves no vhosts (empty server_name scan).
- nginx-regen-certs: --dry-run resolves SANs without an existing cert; a real run still requires one.
- svc-registry: Homebrew 7 launchd labels (sh.brew.<formula>, falling back to homebrew.mxcl.<formula>), so zsvc sees brew-run postgres/redis/nginx.
- Gemfile: declare sqlite3 (zdots-brain sync-history needs it; it had only arrived via ~/.default-gems).
Tests that read machine state instead of fixtures:
- adots_my_structure pins its own profile (work, no remote) instead of reading this machine's.
- update_local_logging stubs pi on PATH.
- platform_e2e uses ZDOTS_POSTGRES_VERSION; services-tier, live-bus, empty-lessons and ztask platform checks skip with reasons when those were never provisioned.
- The zdots_rw fence test skips only when postgres is externally managed (ZDOTS_SKIP_POSTGRES_BREW=1) and that server trusts loopback.
Machine provisioning (not in the diff): installed requirements-lock.txt into mise python (uv, 458 MB); ran zdots-index-tools (119 methodologies); created ~/.local/share/pnpm/bin.
Follow-up (same PR): lib/brew-label.bash now resolves the label for the registry, nginx-ctl, nginx-repair and bootstrap's nginx hints (tests/brew_label.bats); docs and zsvc help no longer hardcode homebrew.mxcl.* or postgresql@18. The nginx scripts' sudo paths were not run (nginx is not installed here).
<!-- SECTION:FINAL_SUMMARY:END -->
