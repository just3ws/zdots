---
id: Z-016
title: Formalize TTY State and Capability Discovery
status: In Progress
assignee: []
created_date: '2026-03-27 17:59'
updated_date: '2026-03-29 16:39'
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
- [ ] #1 Add TTY state section to bin/capabilities reporting stdin/stdout/stderr TTY status, TERM, TERM_PROGRAM, multiplexer detection, and terminal dimensions
- [ ] #2 Guard ZLE widget operations in conf.d/60-bindings.zsh and conf.d/70-integrations.zsh with [[ -o zle ]] checks for defense-in-depth beyond [[ -o interactive ]]
- [ ] #3 Document terminal capability discovery patterns in docs/terminal-capabilities.md covering detection hierarchy, guard patterns, and when to use each
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
