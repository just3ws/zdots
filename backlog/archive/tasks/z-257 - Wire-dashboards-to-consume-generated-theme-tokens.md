---
id: Z-257
title: Wire dashboards to consume generated theme tokens
status: Done
assignee: []
created_date: '2026-07-24 13:12'
updated_date: '2026-07-24 18:56'
labels:
  - platform-dynamism
  - kanagawa
  - agent-ready
dependencies:
  - Z-251
priority: medium
ordinal: 133895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
theme-gen (Z-251) now emits assets/kanagawa-wave/tokens.css and mermaid-theme.json, but the dashboards still hardcode hex. Close the loop so a palette change actually propagates without hand-edits:
- context-engine app.css: replace the hand-authored :root token block with an @import (or build-step copy) of assets/kanagawa-wave/tokens.css.
- bin/zdots-statusd: source the same tokens for its inline CSS :root.
- application.js mermaid themeVariables: load from mermaid-theme.json instead of the inline literal.
- Extend theme-gen to also emit the fzfrc and conf.d/30-env.zsh (LSCOLORS) <scheme>-* branches (currently hand-maintained).
Then 'zdots-theme-gen <scheme> && restart' re-themes literally everything.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 app.css and zdots-statusd derive their :root tokens from the generated tokens.css (no hardcoded palette hex)
- [ ] #2 application.js loads mermaid themeVariables from the generated artifact
- [ ] #3 theme-gen emits the fzfrc + LSCOLORS scheme branches; a palette edit + regen re-themes every surface with no hand edits
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#2 done: application.js fetches public/mermaid-theme.json (synced by bin/deploy from zdots assets) — my repo 4bb2dc9, verified live via injected diagram rendering with generated mainBkg/lineColor. AC#3 done: theme-gen shell_colors builtin emits shell-colors.zsh (ZDOTS_FZF_COLORS + LSCOLORS); 30-env.zsh sources it generically, fzfrc composes from it. All 10 surfaces pass --check; bats green. Follow-up smell (unchanged): context-engine .highlight Rouge theme is base16, not Kanagawa.
<!-- SECTION:NOTES:END -->
