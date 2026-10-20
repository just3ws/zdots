---
id: Z-348
title: 'Implement quick-win tool cache pruners in zdots-hygiene (mise, npm, pnpm)'
status: To Do
assignee: []
created_date: '2026-10-20 15:55'
labels:
  - agent-reported
  - chore
dependencies: []
priority: medium
type: chore
ordinal: 223895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Incorporate non-destructive upstream tool cache cleanup into zdots-hygiene (or under a --tool-caches flag). Reclaim ~10-12 GB from ~/.local/share/mise (5.3 GB via mise prune -y), ~/.npm (4.1 GB via npm cache clean --force), and ~/.local/share/pnpm (3.6 GB via pnpm store prune). Zero risk to personal history or configurations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Preview reclaimable space from mise, npm, and pnpm in zdots-hygiene dry run
- [ ] #2 Execute safe upstream prunes with -f / --tool-caches flag
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
