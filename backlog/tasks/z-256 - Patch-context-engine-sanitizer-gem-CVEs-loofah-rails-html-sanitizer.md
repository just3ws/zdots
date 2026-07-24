---
id: Z-256
title: 'Patch context-engine sanitizer-gem CVEs (loofah, rails-html-sanitizer)'
status: To Do
assignee: []
created_date: '2026-07-24 12:54'
labels:
  - security
  - context-engine
  - agent-ready
dependencies: []
priority: high
ordinal: 132895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Dependabot flagged 6 vulnerabilities on just3ws/my's default branch (1 high, 3 moderate, 2 low) on the 'my' push. bundler-audit on context-engine confirms 4 gem advisories (all transitive, all sanitizer-family, all patch-level fixes):

- loofah 2.25.1 -> >= 2.25.2:
  - GHSA-5qhf-9phg-95m2 (javascript: URIs via numeric char refs w/o semicolons)
  - GHSA-8whx-365g-h9vv (javascript: URIs via named whitespace char refs)
  - GHSA-9wjq-cp2p-hrgf MEDIUM (SVG href bypasses local-reference restriction)
- rails-html-sanitizer 1.7.0 -> >= 1.7.1:
  - GHSA-cj75-f6xr-r4g7 (possible XSS in certain configs)

Fix: 'bundle update loofah rails-html-sanitizer' in ~/my/context-engine, run tests, commit the Gemfile.lock bump. Relevant because context-engine renders operator markdown/HTML (Redcarpet chain) — loopback-only lowers exposure but the sanitizer path should stay patched.

NOTE: bundler-audit reports 4 gem advisories; Dependabot counts 6 — reconcile the 2-advisory gap (likely npm/other on the default branch, or severity double-count) before closing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 loofah >= 2.25.2 and rails-html-sanitizer >= 1.7.1 in context-engine Gemfile.lock; bundler-audit check is clean
- [ ] #2 Test suite passes after the bump; Gemfile.lock committed on the ~/my work branch
- [ ] #3 The 6-vs-4 gap vs Dependabot is reconciled (remaining advisories identified or confirmed resolved)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
