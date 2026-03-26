---
id: Z-004
title: Decouple environment baseline configuration
status: To Do
assignee: []
created_date: '2026-03-26 14:41'
updated_date: '2026-03-26 14:53'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Introduce an explicit configuration mechanism to define the environment baseline (Mac, Linux, CI, etc.) and decouple tool paths from initialization logic. This fixes failures in environments like GitHub Actions (act) where Mac-specific paths like /opt/homebrew don't exist.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create a mechanism for explicit environment baseline declaration (e.g., zdots.env or similar)
- [ ] #2 Update env.sh to respect the explicit baseline and improve auto-detection for Linux/ACT
- [ ] #3 Refactor 10-homebrew.zsh and 90-mise.zsh to use variables instead of hardcoded paths
- [ ] #4 Ensure bin/check passes in minimal/CI environments without Homebrew/Mise when appropriate
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. **Dependency Manifest (`.zdots.env`)**: Define an explicit "Composition Root" that declares required services (e.g., `ZDOTS_SERVICE_PKG_MANAGER="homebrew"`, `ZDOTS_SERVICE_NODE_RUNTIME="mise"`) and their environment-specific settings.
2. **Provider Implementation**: Create a `providers/` directory to house concrete implementations of these services, ensuring each follows a standard "interface" (e.g., `init`, `path_setup`, `validation`).
3. **Dependency Injection Mechanism**: Implement a `zdots_provide` helper in `env.sh` that dynamically loads the configured implementation for a requested service, decoupling the shell from specific tool paths.
4. **Refactor Core Configuration**: Update `conf.d/` scripts to depend on service abstractions rather than concrete paths, applying Dependency Inversion to the shell initialization sequence.
5. **Validation & CI**: Update `bin/check` to perform contract testing against the declared services, ensuring that the environment satisfies the requirements defined in the manifest.
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
