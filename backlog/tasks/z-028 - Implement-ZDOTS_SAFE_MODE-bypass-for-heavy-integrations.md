---
id: Z-028
title: Implement ZDOTS_SAFE_MODE bypass for heavy integrations
status: In Progress
assignee:
  - claude
created_date: '2026-03-29 03:08'
updated_date: '2026-03-29 10:55'
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
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->



## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 When ZDOTS_SAFE_MODE=1, conf.d modules numbered 70+ (integrations, aliases, mise, ai) are skipped
- [ ] #2 A visible diagnostic message is emitted to stderr when safe mode is active
- [ ] #3 Safe mode shell starts successfully — `ZDOTS_SAFE_MODE=1 zsh -i -c exit` returns 0
- [ ] #4 bin/check validates safe mode produces a functional shell with no errors
- [ ] #5 Essential modules (05-60: observability, homebrew, prompt, env, completion, options, bindings) still load in safe mode
<!-- AC:END -->
