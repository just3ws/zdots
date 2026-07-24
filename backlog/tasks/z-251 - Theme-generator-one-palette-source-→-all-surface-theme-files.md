---
id: Z-251
title: 'Theme generator: one palette source → all surface theme files'
status: To Do
assignee: []
created_date: '2026-07-24 12:51'
labels:
  - platform-dynamism
  - kanagawa
  - agent-ready
dependencies: []
priority: high
ordinal: 127895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Kanagawa Wave migration themed ~15 surfaces + 2 dashboards by hand. docs/styleguide/colorschemes.md documents the palette but does not GENERATE anything: changing a palette value today means hand-editing ~15 files, and drift between them is silent.

Build a generator that reads ONE palette source (etc/themes/<name>.yaml — semantic tokens + ANSI 0-15) and EMITS every surface artifact deterministically:
- iTermColors (.itermcolors plist), tmTheme (bat/Sublime), ghostty conf, vivid theme.yml, p10k ANSI-index overrides, fzf --color, LSCOLORS/dircolors, alfred theme.json, lazygit theme.yml, dashboard :root token blocks (my.localhost app.css + zdots-statusd), mermaid themeVariables.
- Idempotent: re-running with an unchanged source is a no-op (regen → diff clean).
- One command: 'zdots-theme-gen <name>' regenerates all; 'zdots-theme-gen --check' fails if any emitted file is stale vs source (wire into zdots-doctor / a contract test).

This makes theming (and re-theming, and adding a scheme) a single edit + one command instead of a 15-file manual sweep. Natural next step from the styleguide — the styleguide becomes the generator's doc.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A single palette source file (etc/themes/kanagawa-wave.yaml) is the sole source of truth for all Kanagawa surface colors
- [ ] #2 zdots-theme-gen <name> regenerates every listed surface artifact from that source, deterministically and idempotently
- [ ] #3 zdots-theme-gen --check exits non-zero when any generated artifact is stale vs the source; wired into a contract test / zdots-doctor
- [ ] #4 Regenerating the current kanagawa-wave source produces a clean diff against the hand-authored files committed this session (proves parity)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
