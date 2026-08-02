---
id: Z-276
title: 'vdots: cache the Python provider probe — 209ms of 777ms startup'
status: Done
assignee: []
created_date: '2026-08-01 09:57'
updated_date: '2026-08-01 16:20'
labels:
  - audit-filed
  - enhancement
dependencies: []
priority: low
ordinal: 152895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
nvim --startuptime: 777ms total; require('editor.options') is 209ms (27%) because has_python_module() at lua/editor/options.lua:93-113 synchronously runs up to 4 Python interpreter launches through mise shims per startup, just to set g.python3_host_prog.

Fix in vdots: cache the resolved python path to stdpath('cache') keyed on shim mtime, or defer provider setup until a remote-plugin needs it. Expected ~570ms startup. (2026-08-01 platform audit, vdots — measured; filed here as the platform tracker, work lands in ~/.config/nvim)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DONE vdots 7ffbe6c: python provider probe cached at stdpath(cache)/python3_host_prog keyed exepath@mtime per candidate; hit = 0 spawns (was 4), ~125ms -> ~2.6ms. Negative result cached too. Known gap in-code: pip install pynvim doesn't bump mtime — delete cache file to re-probe. Remaining ~450-600ms nvim startup lives elsewhere.
<!-- SECTION:NOTES:END -->
