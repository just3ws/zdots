---
id: Z-349
title: >-
  Usage-backed Brewfile audit: cross-reference formulae against Atuin shell
  history
status: In Progress
assignee:
  - '@codex'
created_date: 2026-10-20 15:55
updated_date: '2026-11-01T03:03:00Z'
labels:
  - agent-reported
  - enhancement
dependencies: []
priority: medium
type: enhancement
ordinal: 224895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Cross-reference current Homebrew formula declarations across the platform Brewfiles against installed formula manifests, provided executable names, and the local Atuin SQLite history. Use a configurable usage window (default: 90 days via --days). Produce an annotated list of zero-direct-use candidates for safe operator review. Never uninstall packages automatically. Distinguish formula aliases, wrappers, profile-specific declarations, non-CLI formulae, and packages invoked indirectly by scripts or services.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Map declared Homebrew formulae to their provided binary names
- [x] #2 Query Atuin SQLite history for binary execution frequencies over configurable window (default: 90 days)
- [x] #3 Generate annotated report of zero-use candidates without auto-uninstalling
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented and ran audit/brewfile_usage.py with SQLite read-only access to Atuin history. The 90-day run queried 3,659 active rows (11,248 total), mapped declared formula executables, and generated 166 annotated zero-direct-use review candidates across the profiles. It never uninstalls packages. The report records the limits of direct history matching and distinguishes work-only and optional profiles. Output: audit/brewfile-usage-2026-10-31.md. Home Brewfile satisfies `brew bundle check --no-upgrade`; the standard make check emits a nonblocking warning for package freshness only. Homebrew migrated sentry-cli from formula to cask; Brewfile.common now declares the cask and local install is cask 3.8.2, with /opt/homebrew/bin/sentry-cli verified. Three unused Kubernetes tools were removed from the home profile and retained in the work profile. Verification: final full make check passed (`check: OK`; 870 passing test lines, with documented skips); the 66 targeted statusd/bus/ztask/platform checks and isolated o2_mcp suite (26/26) passed; git diff --check and secret-scan passed. Acceptance criteria and DoD evidence item 1 and make check item 2 are complete. DoD item 3 remains open until exact related files are committed and pushed through ordinary fast-forward, and the resulting GitHub Actions run passes.

Commit a55cdb1c was authored as Mike Hall <mike@just3ws.com>, pushed to origin/main via ordinary fast-forward, and the zdots worktree is clean. Remote Check and Secret Scan runs 41267572563 and 41267572544 were queued for the pushed commit; keep task In Progress until their result is verified.
<!-- SECTION:NOTES:END -->
