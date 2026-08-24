---
id: Z-315
title: >-
  [agent-issue] zdots-storage Backups bucket does not count Postgres dumps
  (~/my/backups) — the 'my' database is unc
status: To Do
assignee: []
created_date: '2026-08-24 13:53'
updated_date: '2026-08-24 13:54'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 190895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

zdots-storage Backups bucket does not count Postgres dumps (~/my/backups) — the 'my' database is uncovered

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Evidence gathered 2026-08-24 while answering operator question C2
("verify that this database is included in the zdots-storage").

**It is not.** `bin/zdots-storage:161-164` defines the Backups bucket as
exactly two paths:

    colima_bak_bytes=$(_dir_bytes "$HOME/.local/state/zsh/colima-xdg-backup")
    adots_bak_bytes=$(_dir_bytes "$HOME/.adots-backups")
    backups_bytes=$(( colima_bak_bytes + adots_bak_bytes ))

No Postgres path is counted. The standing 1.6GB [warn] is 100% `~/.adots-backups`
(colima-xdg-backup is 0B) — so the warning is unrelated to databases, and the
operator's read that "something is already writing backups" does not apply to
Postgres.

`zdots-ctx backup` (bin/zdots-ctx:735) does exist and dumps to
`${MY_ROOT}/backups`, keeping the last 10. Actual state of that directory:

| | |
|---|---|
| Dumps present | 2 |
| Newest | `my_20260515_120829.sql.gz`, **100 days stale** |
| Size | 16KB, against a live KB of 327 lessons + 128 methodologies |
| Scheduled | No launchd/cron job invokes `zdots-ctx backup` |
| Counted by zdots-storage | No |

Request: add `${MY_ROOT}/backups` (or the resolved `~/my/backups`) to the
Backups bucket so the database has storage visibility, and consider whether
`zdots-ctx backup` should have a launchd timer — the operator asked for
"regular backups of the Postgres databases" in round-1 C2.

**Separate finding, NOT for zdots to fix — flagged to the operator directly:**
both dumps are *tracked in git* in `~/my` (`git ls-files backups/` returns
them) and `~/my/.gitignore` has no backup rule. Left untouched deliberately:
untracking them could remove the only offsite copy, so that is the operator's
call, not an agent's.
<!-- SECTION:NOTES:END -->
