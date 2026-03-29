---
id: Z-029
title: Add timeout protection for provider initialization
status: In Progress
assignee: []
created_date: '2026-03-29 03:08'
updated_date: '2026-03-29 22:26'
labels: []
milestone: m-0
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wrap zdots_require calls with a timeout mechanism so a hanging provider cannot block shell startup. Split from Z-011 AC#3.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->



## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add zdots_cmd_timeout helper function to env.sh that wraps commands with timeout/gtimeout when available, falling back to no-timeout gracefully
- [ ] #2 Apply timeout wrapping to slow provider commands: mise activate in node/mise.zsh and python/mise.zsh, ollama list in ai/ollama.zsh
- [ ] #3 Add ZDOTS_PROVIDER_TIMEOUT configurable threshold (default 3s) referenced by zdots_cmd_timeout
- [ ] #4 Add test in bin/check verifying that a simulated slow provider is correctly timed out
<!-- AC:END -->
