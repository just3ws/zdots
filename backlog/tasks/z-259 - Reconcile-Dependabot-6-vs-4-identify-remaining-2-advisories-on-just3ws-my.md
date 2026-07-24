---
id: Z-259
title: 'Reconcile Dependabot 6-vs-4: identify remaining 2 advisories on just3ws/my'
status: To Do
assignee: []
created_date: '2026-07-24 14:01'
labels:
  - security
  - agent-ready
dependencies: []
priority: low
ordinal: 135895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Dependabot reported 6 vulns (1 high, 3 moderate, 2 low) on just3ws/my default branch; bundler-audit found only 4 gem advisories (now fixed in Z-256). Identify the other 2 — likely npm (package-lock) or GitHub-Actions advisories Dependabot tracks but bundler-audit does not. Check the Dependabot alerts page / gh api, then patch or dismiss with rationale.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The 2 non-gem advisories are identified (ecosystem + package) and either patched or dismissed with a recorded reason
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
