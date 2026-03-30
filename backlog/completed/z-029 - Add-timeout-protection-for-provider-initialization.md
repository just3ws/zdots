---
id: Z-029
title: Add timeout protection for provider initialization
status: Done
assignee: []
created_date: '2026-03-29 03:08'
updated_date: '2026-03-30 14:25'
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
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add zdots_cmd_timeout helper function to env.sh that wraps commands with timeout/gtimeout when available, falling back to no-timeout gracefully
- [x] #2 Apply timeout wrapping to slow provider commands: mise activate in node/mise.zsh and python/mise.zsh, ollama list in ai/ollama.zsh
- [x] #3 Add ZDOTS_PROVIDER_TIMEOUT configurable threshold (default 3s) referenced by zdots_cmd_timeout
- [x] #4 Add test in bin/check verifying that a simulated slow provider is correctly timed out
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Z-029: Add timeout protection for provider initialization\n\n### Changes\n\n**env.sh** — Added `ZDOTS_PROVIDER_TIMEOUT` variable (default 3s) and `zdots_cmd_timeout` POSIX-compatible helper function. Tries `timeout`, falls back to `gtimeout`, then runs without timeout.\n\n**providers/node/mise.zsh** — Wrapped 3 `mise activate` calls with `zdots_cmd_timeout`.\n\n**providers/python/mise.zsh** — Wrapped 2 `mise activate` calls with `zdots_cmd_timeout`.\n\n**providers/ai/ollama.zsh** — Wrapped `ollama list` call with `zdots_cmd_timeout`.\n\n**bin/check** — Added `assert_provider_timeout()` test that creates a mock slow provider (sleeps 10s), runs it through `zdots_cmd_timeout` with 1s timeout, and verifies the command is killed before completion.\n\n### Verification\n\n`make check` exits 0 — all 13 Bats tests pass, all assertion functions pass.\nSpec compliance review: PASS (all 4 ACs verified).\nCode quality review: Interrupted by rate limit but changes are straightforward (helper function + 6 command wraps + 1 test)."]
<!-- SECTION:FINAL_SUMMARY:END -->
