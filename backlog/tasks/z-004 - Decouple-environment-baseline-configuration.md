---
id: Z-004
title: Decouple environment baseline configuration
status: To Do
assignee: []
created_date: '2026-03-26 14:41'
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

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
