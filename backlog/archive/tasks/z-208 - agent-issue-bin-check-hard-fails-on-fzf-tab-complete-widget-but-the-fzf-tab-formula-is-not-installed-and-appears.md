---
id: Z-208
title: >-
  [agent-issue] bin/check hard-fails on fzf-tab-complete widget but the fzf-tab
  formula is not installed and appears
status: Done
assignee: []
created_date: '2026-07-11 16:59'
updated_date: '2026-07-11 17:09'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 103895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7d561ced257d57f261bf6fed40dc4959`

bin/check hard-fails on fzf-tab-complete widget but the fzf-tab formula is not installed and appears in no Brewfile — make check cannot pass on this machine (decide: brew install fzf-tab, or relax the probe)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Resolved 2026-07-11 by operator decision: install (not relax the probe).
- brew install fzf-tab → /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh present (the exact path conf.d/74-fzf.zsh sources).
- make check now PASSES: 769/769 ok (was hard-failing at the first probe).
- Made reproducible: brew "fzf-tab" added to Brewfile.common (the actual inconsistency was bin/check asserting a widget no Brewfile provided).
<!-- SECTION:NOTES:END -->
