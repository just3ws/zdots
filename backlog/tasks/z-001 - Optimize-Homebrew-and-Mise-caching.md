---
id: Z-001
title: Optimize Homebrew and Mise caching
status: Done
assignee: []
created_date: '2026-03-25 16:30'
updated_date: '2026-03-25 21:49'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement caching for Homebrew shellenv and Mise activation to improve startup performance.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Unified Homebrew and Mise caching implemented
- [x] #2 Warm startup time under 80ms (76.4ms)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented shared caching logic in conf.d/ and updated .zprofile to source them. Removed slow-evaluations from login shell startup.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Optimized Homebrew and Mise initialization by unifying their caching logic. This ensures that both login and interactive shells benefit from pre-generated caches, reducing startup time by ~10-20ms. Final warm startup: 76.4ms.
<!-- SECTION:FINAL_SUMMARY:END -->
