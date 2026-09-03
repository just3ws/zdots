---
id: Z-338
title: >-
  [agent-issue] conf.d/08-local-bin chpwd hook evicts .zshrc.local's permanent
  PATH appends (~/.config/nvim/bin, jus
status: Done
assignee: []
created_date: '2026-09-03 01:30'
updated_date: '2026-09-03 01:42'
labels:
  - agent-reported
  - bug
dependencies:
  - Z-337
priority: medium
ordinal: 213895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Severity:** medium
**Trace ID:** `51a96ef723d9121d483864d519bd4b0b`

conf.d/08-local-bin chpwd hook evicts .zshrc.local's permanent PATH appends (~/.config/nvim/bin, just3ws.github.io/bin) after cwd passes through that repo

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Root cause

`conf.d/08-local-bin.zsh` `_zdots_chpwd_local_bin` treats `$PWD/bin` as
*owned solely by the hook*. On `chpwd` it does:

    path=("${(@)path:#${_zdots_local_bin_prev}}")   # remove ALL occurrences

`.zshrc.local` (interim, per Z-337) permanently `path+=`s two dirs that are
*also* repo `bin/` dirs:
  - `~/.config/nvim/bin`            (vdots shim)
  - `~/github.com/just3ws/just3ws.github.io/bin`

Sequence that breaks it:
1. shell init: `.zshrc.local` appends `~/.config/nvim/bin` to PATH.
2. `cd ~/.config/nvim` → hook prepends `$PWD/bin`, sets
   `_zdots_local_bin_prev=~/.config/nvim/bin`.
3. `cd` anywhere else → `new_bin != prev`, hook runs the `:#` removal →
   **every** copy of `~/.config/nvim/bin` is stripped, including the
   permanent one from step 1. Never re-added until next shell.

Observed: `vdots-publish` resolves fine early in a session, then
`command not found` after the cwd has visited `~/.config/nvim` and left
(`hash -r` just exposes it — the dir is genuinely off PATH).

## Fix options (operator's call)

- Hook tracks only the entry *it* added (guard: don't remove a dir that was
  on PATH before the hook prepended it), or
- Z-337 lands `_zdots_path_add ~/.config/nvim/bin` in env.sh §9c AND the
  hook skips removal of any dir still marked as a "native" PATH member, or
- Hook keeps a set of "sticky" repo-bin dirs it must never evict.

Z-337 alone is **not** sufficient — the hook would evict an env.sh-added
entry the same way.

## Interim workaround (user)

`source ~/.config/zsh/.zshrc.local` re-appends both dirs, or run the tool
from inside `~/.config/nvim`, or `~/.config/nvim/bin/vdots-publish …` by
full path.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in `conf.d/08-local-bin.zsh`. The chpwd hook now (1) tracks only the
entry it prepended itself (`_zdots_local_bin_added`) and removes just that on
the way out, (2) never adopts a `$PWD/bin` already on PATH — a sticky dir from
`env.sh`/`.zshrc.local` (e.g. `~/.config/nvim/bin`) is left untouched, (3)
primes via a one-shot `precmd` instead of an immediate call, so a shell
started inside such a repo doesn't adopt-then-evict its bin before
`.zshrc.local` has run.

`.zshrc.local` appends made idempotent (index guard) so a manual re-`source`
can't double-add.

Tests: `tests/local_bin_path.bats` (6 hermetic cases, added to
`tests/ci-allowlist.txt`). Blink test: cases 4–5 (the Z-338 regression) go red
on `git stash` of the hook, green on restore. Verified in a real interactive
`zsh -ic`: `cd ~/.config/nvim && cd /tmp` leaves `~/.config/nvim/bin` and
`just3ws.github.io/bin` on PATH with no dupes; a genuine transient project
`bin/` is still added on enter and removed on leave.

Z-337 (native env.sh pickup) still stands as the way to drop the interim
`.zshrc.local` block; this fix makes the hook correct regardless of which
mechanism adds the dir.
<!-- SECTION:FINAL_SUMMARY:END -->
