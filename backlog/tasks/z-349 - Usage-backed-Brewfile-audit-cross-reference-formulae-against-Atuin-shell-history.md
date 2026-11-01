---
id: Z-349
title: >-
  Usage-backed Brewfile audit: cross-reference formulae against Atuin shell
  history
status: Done
assignee:
  - '@codex'
created_date: 2026-10-20 15:55
updated_date: '2026-11-01T03:46:00Z'
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
Audited all declared Homebrew formulae against provided executables and the rolling 90-day Atuin history using read-only SQLite. Report: audit/brewfile-usage-2026-10-31.md (3,662 active rows; 165 review-only zero-direct-use candidates; no automatic removals). Removed sentry-cli after operator confirmed it is unused; removed the declaration from Brewfile.common, uninstalled its cask, and regenerated the report. Home Brewfile check passes. Full make check passed; Check and Secret Scan for commit 9f2549da passed (41268639876, 41268639863). All acceptance criteria and Definition of Done items are complete; changes are pushed under Mike Hall <mike@just3ws.com> via ordinary fast-forward.
<!-- SECTION:NOTES:END -->
