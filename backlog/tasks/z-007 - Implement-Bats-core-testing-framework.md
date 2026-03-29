---
id: Z-007
title: Implement Bats-core testing framework
status: Done
assignee:
  - '@myself'
created_date: '2026-03-26 16:20'
updated_date: '2026-03-29 03:09'
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
- [x] #1 Add bats-core and helpers (bats-assert, bats-support) to the environment
- [x] #2 Create tests/ directory structure
- [x] #3 Migrate core env.sh tests to Bats
- [x] #4 Implement Zsh-specific observability tests in Bats
- [x] #5 Integrate Bats execution into bin/check and CI pipeline
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. **Framework Installation**: Add `bats-core`, `bats-assert`, and `bats-support` to the `Brewfile` and install them.
2. **Directory Structure**: Create a `tests/` directory with `setup.bash` to bootstrap the Zdots environment for tests.
3. **POSIX Contract Testing**: Create `tests/env_posix.bats` to verify that `env.sh` remains compatible with standard `sh` and `bash` while setting expected XDG paths.
4. **Zsh-Specific Testing**: Create `tests/observability.bats` to test the Zsh-only control plane (Trace ID, Span rotation, Traceparent) by invoking `zsh -i` within Bats.
5. **Runner Integration**: Update `bin/check` to execute `bats tests/` as part of the primary regression suite.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented Bats-core testing framework for Zdots. 1. Added bats-core and helpers to Brewfile. 2. Created tests/ directory with setup.bash for environment bootstrapping. 3. Implemented POSIX contract tests in env_posix.bats and verified compatibility with bash. 4. Added Zsh-specific observability tests in observability.bats. 5. Integrated Bats into the main bin/check regression suite.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Integrated Bats-core for standardized testing of both POSIX and Zsh-specific environment logic.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
