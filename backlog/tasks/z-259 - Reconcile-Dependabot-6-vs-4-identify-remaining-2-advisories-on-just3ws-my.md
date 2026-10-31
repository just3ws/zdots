---
id: Z-259
title: Reconcile my Dependabot alerts after Pi lock refresh
status: Done
assignee: []
created_date: 2026-07-24 14:01
updated_date: '2026-10-31T23:03:00Z'
labels:
  - security
  - agent-ready
dependencies: []
priority: low
ordinal: 135895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Original trigger: Dependabot showed six findings while bundler-audit showed four gem advisories (those were handled under Z-256). Re-audit on 2026-10-31 found the active root npm lock was still on Pi 0.84.2 and reported nested undici/brace-expansion advisories. Updated and pushed the lock on dad1e6f: Pi 1.4.0, minimatch 11.0.1, undici 8.12.2; npm audit reports zero vulnerabilities. GitHub now reports zero open alerts for my: 14 stale root-package alerts were dismissed as inaccurate after checking the current manifest, and the archived JSON alert was dismissed as not_used after confirming the Gemfile is only under .archive/_archive and has no active references. The archived lock snapshot remains unchanged.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The active root npm dependency tree is on the latest supported Pi package and has no known vulnerabilities.
- [x] #2 GitHub Dependabot records for current root dependencies match the committed lock, or remaining API/snapshot limits are documented with evidence.
- [x] #3 The archived Gemfile.lock advisory has an explicit disposition without silently rewriting the archive snapshot.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All related changes committed — git status clean for files touched by this task
- [x] #2 The lockfile audit is clean and the current GitHub alert state is recorded.
- [x] #3 All changed files are committed and pushed; unrelated private untracked data remains untouched.
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31: npm registry reported @earendil-works/pi-coding-agent 1.4.0 as latest (same Node >=22.19 floor). `npm update --package-lock-only --ignore-scripts` refreshed the lock; overrides pin patched minimatch 11.0.1 and undici 8.12.2. `npm audit` reports zero vulnerabilities; package JSON parse and `git diff --check` pass. Gitleaks scanned only the staged diff with no findings. Commit dad1e6f is pushed and matches origin/main. Dependabot now reports 0 open / 15 dismissed / 74 fixed alerts for my; the 14 root lock alerts were stale and dismissed as inaccurate, and archived alert #67 was dismissed as not_used. Both zdots and my report zero open alerts. Local private untracked SQLite databases and vault remain untouched.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Completed on 2026-10-31. Refreshed `my/package-lock.json` from Pi 0.84.2 to 1.4.0, pinned patched minimatch 11.0.1 and undici 8.12.2 through npm overrides, and verified `npm audit` reports zero vulnerabilities. Commit dad1e6f is pushed and matches origin/main. GitHub now shows 0 open Dependabot alerts for my (15 dismissed: 14 stale root-package records dismissed as inaccurate after verification, plus archived JSON finding dismissed as not_used; 74 fixed). The archived `.archive/_archive/Gemfile.lock` was verified inactive and left unchanged. Private untracked SQLite databases and vault were preserved.
<!-- SECTION:FINAL_SUMMARY:END -->
