---
id: Z-028
title: Implement ZDOTS_SAFE_MODE bypass for heavy integrations
status: Done
assignee:
  - claude
created_date: '2026-03-29 03:08'
updated_date: '2026-03-29 16:29'
labels: []
milestone: m-0
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When ZDOTS_SAFE_MODE=1, skip non-essential conf.d modules (AI, integrations, heavy completions) to provide a minimal safe shell for debugging. Split from Z-011 AC#2.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 When ZDOTS_SAFE_MODE=1, conf.d modules numbered 70+ (integrations, aliases, mise, ai) are skipped
- [x] #2 A visible diagnostic message is emitted to stderr when safe mode is active
- [x] #3 Safe mode shell starts successfully — `ZDOTS_SAFE_MODE=1 zsh -i -c exit` returns 0
- [x] #4 bin/check validates safe mode produces a functional shell with no errors
- [x] #5 Essential modules (05-60: observability, homebrew, prompt, env, completion, options, bindings) still load in safe mode
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented ZDOTS_SAFE_MODE bypass for heavy integrations.\n\n**Changes:**\n- `.zshrc`: When `ZDOTS_SAFE_MODE=1`, conf.d modules numbered 70+ are skipped via `[7-9]*` glob match. Diagnostic message emitted to stderr. `zdefer`-dependent syntax highlighting guarded.\n- `bin/check`: Added `assert_safe_mode()` — validates clean exit, checks for unexpected stderr, confirms diagnostic message, verifies essential modules loaded (ZDOTS_TRACE_ID present).\n\n**Evidence:**\n- `make check` exits 0 (13/13 Bats tests pass, all assertions pass)\n- `ZDOTS_SAFE_MODE=1 zsh -i -c exit` returns 0 with diagnostic message\n- Code quality reviewer found redundant sub-shell; fixed in follow-up commit\n\n**Commits:** `2af43f2` (feat), `cbfd1a8` (refactor)
<!-- SECTION:FINAL_SUMMARY:END -->
