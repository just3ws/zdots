---
id: Z-325
title: '[agent-issue] nginx-regen-certs has no way to drop a stale SAN'
status: Done
assignee: []
created_date: '2026-08-26 18:59'
updated_date: '2026-09-01 13:16'
labels:
  - agent-reported
  - request
dependencies: []
priority: low
ordinal: 200895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** low
**Trace ID:** `670b410751ba35a052c13a5e0e60669f`

wwworkremote/core switched its trusted-LAN name from wwworkremote.home.arpa/wwwr.home.arpa to a real DNS record, lan.wwworkremote.com, and removed the .home.arpa names from every live source (vhost server_name, Rails config.hosts). But the two .home.arpa names are still in the deployed cert's SAN list after a fresh nginx-regen-certs run, because the script unions with whatever's already in the current cert by design (per its own header: 'so a name that already worked is never silently dropped') -- it only ever adds, never drops. Not a functional problem (an unused SAN in a private mkcert cert is harmless), just asking whether a --prune/--reset mode makes sense: rebuild the SAN list purely from currently-live sources (Z-324's deployed-vhost server_name scan plus the .local/.localhost HOSTS array plus the hardcoded baseline), skipping the union with the existing cert, so a name that's no longer served anywhere actually falls out over time. Did not attempt this myself since the cert is shared across 7+ other apps (llama, embed, o2, zdots, my, just3ws, gemstash) and bypassing the script's own safety wrapper to hand-run mkcert felt like the wrong call for shared infra.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added --prune to bin/nginx-regen-certs: skips the union-with-existing-cert seed (lines that openssl-read the current cert's SANs), rebuilding the list purely from live sources — deployed vhost server_name + zdots.localhost + loopback. Prints 'dropping N SAN(s) no longer served: ...' before regen so drops are visible on shared infra. --dry-run --prune shows the resolved set + drops, changes nothing. Default (no flag) behaviour unchanged: still unions, still never drops. In this env --prune drops zdots.local, wwworkremote.home.arpa, wwwr.home.arpa (14 SANs vs 17). man page + tests/nginx_regen_certs.bats added. Did NOT run the real regen (sudo, shared cert across 7+ apps) — operator runs 'nginx-regen-certs --prune' when ready.
<!-- SECTION:NOTES:END -->
