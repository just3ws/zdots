---
id: Z-337
title: >-
  [agent-issue] env.sh §9c: put ~/.config/nvim/bin (vdots) on PATH natively.
  vdots now has a control-plane shim (bin
status: To Do
assignee: []
created_date: '2026-09-02 19:57'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 212895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `51a96ef723d9121d483864d519bd4b0b`

env.sh §9c: put ~/.config/nvim/bin (vdots) on PATH natively. vdots now has a control-plane shim (bin/vdots -> vdots-{ctl,doctor,update,read}) matching the zdots/phx pattern, but its bin dir is wired nowhere — adots gets ~/bin via _zdots_path_add at env.sh:336, zdots/bin via conf.d/01-zdots-bin.zsh, vdots has no equivalent. Ask: add one _zdots_path_add "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/bin" line in §9c next to the $HOME/bin one (optionally behind a VDOTS_BIN_DIR var for symmetry with ADOTS_BIN_DIR). Bigger option: make vdots a third peer in lib/peer-bootstrap.bash + the session capability banner (zdots-doctor already has a vdots beacon section). Interim in place: ~/.config/zsh/.zshrc.local appends the dir for interactive shells; remove that block when this lands.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
