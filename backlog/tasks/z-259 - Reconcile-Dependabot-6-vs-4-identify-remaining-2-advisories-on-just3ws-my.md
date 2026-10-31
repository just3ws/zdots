---
id: Z-259
title: Reconcile my Dependabot alerts after Pi lock refresh
status: In Progress
assignee: []
created_date: 2026-07-24 14:01
updated_date: '2026-10-31T23:02:00Z'
labels:
  - security
  - agent-ready
dependencies: []
priority: low
ordinal: 135895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Original trigger: Dependabot showed six findings while bundler-audit showed four gem advisories (those were handled under Z-256). Re-audit on 2026-10-31 found the active root npm lock was still on Pi 0.84.2 and reported advisories for nested undici/brace-expansion. Updated and pushed the lock on dad1e6f: Pi 1.4.0, minimatch 11.0.1, undici 8.12.2; npm audit now reports zero vulnerabilities. GitHub alert records lag the pushed lock: 12 were dismissed as inaccurate after verifying their manifest versions were stale; two undici alerts remain open because the API rejected further updates for missing admin:repo_hook scope. A separate low-severity alert remains in .archive/_archive/Gemfile.lock (json 2.19.5); keep the archived snapshot unchanged until its disposition is chosen.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The active root npm dependency tree is on the latest supported Pi package and has no known vulnerabilities.
- [ ] #2 GitHub Dependabot records for current root dependencies match the committed lock, or remaining API/snapshot limits are documented with evidence.
- [ ] #3 The archived Gemfile.lock advisory has an explicit disposition without silently rewriting the archive snapshot.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All related changes committed — git status clean for files touched by this task
- [ ] #2 The lockfile audit is clean and the current GitHub alert state is recorded.
- [ ] #3 All changed files are committed and pushed; unrelated private untracked data remains untouched.
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31: npm registry reported @earendil-works/pi-coding-agent 1.4.0 as latest (same Node >=22.19 floor). `npm update --package-lock-only --ignore-scripts` updated the lock; overrides were added for patched minimatch 11.0.1 and undici 8.12.2. `npm audit` reported zero vulnerabilities; lock/package JSON parse and git diff --check passed. Gitleaks scanned only the staged diff; no findings. Commit dad1e6f pushed to origin/main; branch synced. GitHub alert API had stale manifest versions; after dismissing the 12 already stale records, further alert updates returned an API scope rejection (admin:repo_hook). Remaining alert IDs 77/78 are still open for undici despite current lock 8.12.2; archived alert #67 is on `.archive/_archive/Gemfile.lock`, json 2.19.5 -> patched 2.19.9.
<!-- SECTION:NOTES:END -->
