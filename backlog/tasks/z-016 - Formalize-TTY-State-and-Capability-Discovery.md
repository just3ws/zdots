---
id: Z-016
title: Formalize TTY State and Capability Discovery
status: To Do
assignee: []
created_date: '2026-03-27 17:59'
updated_date: '2026-03-29 03:13'
labels: []
milestone: m-0
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Improve shell resilience by formalizing how the environment detects and adapts to TTY states (interactive vs. non-interactive, TTY vs. non-TTY). This includes robust discovery of terminal capabilities beyond basic TERM variables.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Implement bin/capabilities check for TTY state
- [ ] #2 Refine ZLE widget loading to be TTY-aware
- [ ] #3 Document terminal capability discovery logic
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
