---
id: Z-314
title: '[agent-issue] zdots-issue files into the caller''s backlog, not zdots'''
status: Done
assignee: []
created_date: '2026-08-23 14:58'
updated_date: '2026-08-26 18:01'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 189895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7f07527c6264181a781c0011069b470b`

WHAT I RAN
From /Users/mike/github.com/wwworkremote/core (a repo with its own Backlog.md tracker):
  zdots-issue --type request --severity high --title '...' '<description>'

WHAT HAPPENED
The issue was created as TASK-84 in the wwworkremote/core backlog. It never reached zdots. The command reported 'zdots-issue: filed (unknown ID)'.

WHAT I EXPECTED
The issue to be filed in the zdots backlog as Z-NNN, regardless of where I was standing when I ran it.

ROOT CAUSE
bin/zdots-issue:137 runs 'backlog task create ...' with no directory pinning, so backlog resolves the tracker from the current working directory. Any agent that files from inside another Backlog.md-using repo silently files against that repo instead.

The 'unknown ID' message is the tell: the ID regex at :146 expects 'Task Z-[0-9]+', and the foreign tracker returned 'task-84', so extraction failed. The failure was reported as a cosmetic unknown-ID rather than as a misroute, which is why I only caught it by listing backlog/tasks/ afterward.

IMPACT
Silent cross-contamination in both directions: zdots issues land in unrelated project backlogs, and those projects get agent-reported noise they did not ask for. I had to delete the stray TASK-84 from wwworkremote/core by hand and re-file from ~/.config/zsh, which produced Z-313 correctly.

SUGGESTION (operator's call -- not patching this myself)
Pin the tracker explicitly, e.g. run backlog with cwd forced to ${ZDOTDIR:-$HOME/.config/zsh}. Separately, treat a non-Z task ID as a hard error rather than 'unknown ID', since that is exactly the misroute signal.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-08-26 17:53
---
Reproduced live again 2026-08-26 while filing Z-324 from wwworkremote/core: zdots-issue silently filed into that repo's own Backlog.md as task-91 (deleted after discovery) instead of erroring. Two independent agents hitting the identical failure a repo apart — bumping medium -> high.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Pinned `backlog task create` to `${ZDOTDIR:-$HOME/.config/zsh}` via a subshell cd in bin/zdots-issue, and turned the "unknown ID" silent-success fallback into a hard `exit 1`. Verified with the Blink Test: green (fix, filed correctly as Z-325 from ~/my) -> red (fix reverted, misroute reproduced) -> green (fix reapplied). Commit 2e68ef32.
<!-- SECTION:FINAL_SUMMARY:END -->
