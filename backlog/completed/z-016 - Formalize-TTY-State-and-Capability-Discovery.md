---
id: Z-016
title: Formalize TTY State and Capability Discovery
status: Done
assignee: []
created_date: '2026-03-27 17:59'
updated_date: '2026-03-29 22:16'
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
- [x] #1 Add TTY state section to bin/capabilities reporting stdin/stdout/stderr TTY status, TERM, TERM_PROGRAM, multiplexer detection, and terminal dimensions
- [x] #2 Guard ZLE widget operations in conf.d/60-bindings.zsh and conf.d/70-integrations.zsh with [[ -o zle ]] checks for defense-in-depth beyond [[ -o interactive ]]
- [x] #3 Document terminal capability discovery patterns in docs/terminal-capabilities.md covering detection hierarchy, guard patterns, and when to use each
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Z-016: Formalize TTY State and Capability Discovery\n\n### Changes\n\n**bin/capabilities** — Added \"Terminal State\" section reporting stdin/stdout/stderr TTY status, TERM, TERM_PROGRAM, multiplexer detection (TMUX env var + TERM prefix), and terminal dimensions. Both text and JSON output modes supported.\n\n**conf.d/60-bindings.zsh** — Guard changed from `[[ -o interactive ]]` to `[[ -o interactive && -o zle ]]`.\n\n**conf.d/70-integrations.zsh** — Added `&& -o zle` to 5 guard locations: fzf sourcing, fzfrc sourcing, Tab binding block, Ctrl-R binding block. Wrapped history-substring-search bindings in new `[[ -o interactive && -o zle ]]` guard.\n\n**.zshrc** — Wrapped vi-mode/emacs-motion bindkey calls in `[[ -o interactive && -o zle ]]` for consistency.\n\n**bin/check** — Added `assert_zle_guard()` test that sources .zshrc in a non-ZLE `zsh -c` subshell and verifies no ZLE errors leak through.\n\n**docs/terminal-capabilities.md** — New documentation covering detection hierarchy (interactive → ZLE → TTY fd), guard pattern reference table, multiplexer detection, and guidelines for adding new guards.\n\n### Verification\n\n`make check` exits 0 — all 13 Bats tests pass, all assertion functions pass including new `assert_zle_guard`.\n\nSpec compliance review: PASS (all 3 ACs verified).\nCode quality review: APPROVED (two items addressed in follow-up commit).\n\n### Commits\n\n- `0471ad9` feat: formalize TTY state and capability discovery\n- Follow-up: refactor: guard .zshrc bindkey calls with zle check and clarify test scope"]
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
