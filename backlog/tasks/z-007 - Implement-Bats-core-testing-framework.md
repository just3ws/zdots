---
id: Z-007
title: Implement Bats-core testing framework
status: To Do
assignee: []
created_date: '2026-03-26 16:20'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate Bats-core into the repository to provide a standardized, POSIX-compliant testing framework. This will replace/augment the custom logic in bin/check and enable TDD for both env.sh and Zsh-specific features.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add bats-core and helpers (bats-assert, bats-support) to the environment
- [ ] #2 Create tests/ directory structure
- [ ] #3 Migrate core env.sh tests to Bats
- [ ] #4 Implement Zsh-specific observability tests in Bats
- [ ] #5 Integrate Bats execution into bin/check and CI pipeline
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
