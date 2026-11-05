---
id: Z-358
title: '[agent-issue] Add GitHub public profile metadata tooling'
status: Done
assignee: []
created_date: '2026-11-02T19:35:00Z'
updated_date: '2026-11-05T01:17:00Z'
labels:
  - agent-reported
  - request
dependencies: []
documentation:
  - docs/github-public-metadata.md
  - docs/zdots-gh.md
  - docs/tooling.md
priority: medium
ordinal: 229895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `1de609fd72b17f79643e48967c7100f6`

Task: reconcile a user-owned GitHub profile biography and public repository descriptions with canonical profile copy. I checked the zdots command catalog and zdots-gh; they cover delivery-health analysis, not read/update of GitHub profile or repository metadata. Please add a safe zdots wrapper or document a supported workflow for reviewing and updating these public metadata fields without exposing credentials.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document a credential-safe, review-first workflow for profile biographies and repository descriptions.
- [x] #2 Link the workflow from the GitHub tooling documentation and remove token-extraction guidance from the existing zdots-gh run instructions.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Markdown lint and git diff whitespace checks pass.
<!-- DOD:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a credential-safe GitHub public metadata runbook covering account verification, read-before-write review, separate profile and repository updates, and read-back verification. Linked it from tooling and zdots-gh documentation, and removed token extraction from the zdots-gh workflow example.
<!-- SECTION:FINAL_SUMMARY:END -->
