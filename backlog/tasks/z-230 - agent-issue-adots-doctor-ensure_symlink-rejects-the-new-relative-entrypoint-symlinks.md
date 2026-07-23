---
id: Z-230
title: >-
  [agent-issue] adots-doctor ensure_symlink rejects the new relative entrypoint
  symlinks
status: To Do
assignee: []
created_date: '2026-07-15 18:50'
updated_date: '2026-07-23 12:18'
labels:
  - agent-reported
  - error
dependencies: []
priority: low
ordinal: 109895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** low
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

zdots doctor closes the session with adots-doctor exit 1: '.bash_profile is not the expected symlink'. bin/adots-doctor:331 does ensure_symlink ".bash_profile" "$ZDOTDIR/bash_profile" — comparing against the absolute target — but this morning's adots squash deliberately converted ~/.bash_profile, ~/.bashrc, ~/.zshenv to RELATIVE symlinks (.config/zsh/bash_profile), which resolve correctly (verified: readlink resolves, targets exist). The check is stale against its own repo's fix. Expected: ensure_symlink compares fully-resolved paths (e.g. via realpath on both sides) so relative and absolute spellings of the same target both pass.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reproduced again 2026-07-23: adots-doctor still FAILs on .bash_profile symlink check. Confirmed not a real issue — readlink shows valid relative symlink (.config/zsh/bash_profile), target resolves and is readable. Same stale absolute-path comparison in ensure_symlink. No fix applied (not zdots'/agent's to patch per filed-issue note).
<!-- SECTION:NOTES:END -->
