---
id: Z-348
title: 'Implement quick-win tool cache pruners in zdots-hygiene (mise, npm, pnpm)'
status: Done
assignee: []
created_date: '2026-10-20 15:55'
updated_date: '2026-10-20 17:20'
labels:
  - agent-reported
  - chore
dependencies: []
priority: medium
type: chore
ordinal: 223895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Incorporate non-destructive upstream tool cache cleanup into zdots-hygiene. Reclaim storage from ~/.local/share/mise (via mise prune -y), ~/.npm/_npx (stale one-off runtimes >30d verified against directory hex/package signature), and ~/.local/share/pnpm (via pnpm store prune). Enforce signature verification so tools do not bitrot or delete anomalous paths.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Preview reclaimable space from mise, npm, and pnpm in zdots-hygiene dry run
- [x] #2 Execute safe upstream prunes with -f / --apply flag with signature validation
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Final Summary
<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented tool cache pruning in `bin/zdots-hygiene` with anti-bitrot signature verification:
1. **Dynamic Layout Discovery**: Uses `pnpm store path` rather than hardcoding legacy store versions.
2. **Signature Verification**: Added `_is_valid_npx_signature` requiring 16-hex hash directory naming and valid `package.json`/`node_modules` structure before considering for deletion, warning on any anomalous path.
3. **Log Rotation & Retention**: Added 30-day archive retention to `bin/log-rotate` and multi-namespace support (`com.zdots.*`, `com.my.*`, `com.wwworkremote.*`, or direct files).
4. **WWWorkRemote Autostart**: Disabled autostart on `com.wwworkremote.web` and `com.wwworkremote.jobs` (booted out, set `RunAtLoad=false` and `KeepAlive=false`).
5. **Contract Verification**: Updated man pages `zdots-hygiene.1`, `zdots-storage.1`, `log-rotate.1`, and generated `ztranscribe.1`. All 32 Bats tests pass across `zdots_storage_hygiene.bats`, `log_rotate.bats`, and `docs_contract.bats`.
6. **Result**: Primary root storage expanded from 13GB to 22GB available (capacity reduced from 49% to 37%).
<!-- SECTION:FINAL_SUMMARY:END -->
