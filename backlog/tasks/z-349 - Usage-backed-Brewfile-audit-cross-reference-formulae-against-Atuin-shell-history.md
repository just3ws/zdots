---
id: Z-349
title: >-
  Usage-backed Brewfile audit: cross-reference formulae against Atuin shell
  history
status: In Progress
assignee:
  - '@codex'
created_date: 2026-10-20 15:55
updated_date: '2026-11-01T00:06:00Z'
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
- [ ] #1 Map declared Homebrew formulae to their provided binary names
- [ ] #2 Query Atuin SQLite history for binary execution frequencies over configurable window (default: 90 days)
- [ ] #3 Generate annotated report of zero-use candidates without auto-uninstalling
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Inventory update (2026-10-31): Homebrew formula manifests resolve to 228 unique formula names across Brewfile.common/home/work and the optional Rails modernization file; 219 installed-on-request formulae were present before the Kubernetes removal. A 90-day read-only Atuin query covered 3,659 active history rows and found direct binary invocations for 23 formula packages. Treat zero counts as review signals only: aliases, wrappers, scripts, service use, and project dependencies make shell-history absence insufficient grounds to uninstall.

Corrected sentry-cli from cask to formula, updated the whisper.cpp declaration to Homebrew’s canonical name, and removed k9s/kubernetes-cli/kubectx from the personal Brewfile. Those three tools had no recorded direct invocations in the window and no installed formula dependents; Homebrew removed about 259 MB. They remain in Brewfile.work. `brew bundle check --no-upgrade --file=Brewfile.home` now passes. The kube config under the home directory was not touched.

Storage snapshot: Cellar 10 GB, Caskroom 818 MB, Homebrew cache 44 MB, internal free space 54 GiB (45 GiB operating reserve). `brew cleanup --dry-run` reports only 4.7 MB reclaimable. The installed but undeclared libarchive, nss, and xz leaves total about 25.7 MB and have no installed formula dependents; keep pending usage/context review. The fixed-window analysis and manually generated candidate output do not yet satisfy the reusable --days/report acceptance criterion.
<!-- SECTION:NOTES:END -->
