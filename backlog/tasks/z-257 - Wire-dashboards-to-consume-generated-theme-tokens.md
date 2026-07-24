---
id: Z-257
title: Wire dashboards to consume generated theme tokens
status: To Do
assignee: []
created_date: '2026-07-24 13:12'
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
