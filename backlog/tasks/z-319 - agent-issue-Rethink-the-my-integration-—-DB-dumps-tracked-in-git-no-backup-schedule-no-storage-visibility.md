---
id: Z-319
title: >-
  [agent-issue] Rethink the 'my' integration — DB dumps tracked in git, no
  backup schedule, no storage visibility
status: To Do
assignee: []
created_date: '2026-08-24 16:45'
updated_date: '2026-08-24 16:45'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 194895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

Rethink the 'my' integration — DB dumps tracked in git, no backup schedule, no storage visibility

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Filed at the operator's request (round-3 B3): "I need to rethink the My
integration entirely. Yes, submit a zdots-issue on this topic with these
observations." Scope is the rethink; the observations below are the evidence.

**1. Postgres dumps are tracked in git.** `git ls-files backups/` in `~/my`
returns both dumps, and `~/my/.gitignore` has no rule for them. `my` is
private, so this is not a leak, but committed dumps bloat history permanently
and a private repo that later goes public leaks retroactively. Not untracked
by an agent: they may be the only offsite copy, and removing them from
*history* is a rewrite that needs an explicit decision.

**2. There is no backup schedule.** `zdots-ctx backup` (bin/zdots-ctx:735)
exists and keeps the last 10, but nothing invokes it — no launchd job, no cron.
The two dumps present are 2026-05-12 and 2026-05-15. As of 2026-08-24 the
newest is 100 days old and 16KB, against a live knowledge base of 327 lessons
and 128 methodologies. That is not a backup system; it is two snapshots.

**3. Storage has no visibility into it** — tracked separately as Z-315.
`bin/zdots-storage` counts only `colima-xdg-backup` and `.adots-backups`, so
`${MY_ROOT}/backups` is invisible and the standing 1.6GB [warn] is entirely
`.adots-backups`, unrelated to databases.

**4. The schema owner boundary is doing real work and is worth preserving in
whatever replaces this.** context-engine has no `db/migrate` of its own; the
`my` database schema is owned by zdots' `db/migrations/` and applied with
`zdots-ctx migrate`. That split caught three real defects this month (Z-241,
Z-316, Z-317) where the Rails app used columns the schema never had. Whatever
the rethink lands on, losing that seam would lose the check.

**5. The test database is a separate migration target.** `zdots-ctx migrate`
defaults to `postgresql:///my`; `my_test` needs
`ZDOTS_MIGRATION_URL=postgresql:///my_test zdots-ctx migrate` as a second,
easily-forgotten step. Applying to `my` alone leaves the suite failing against
a stale schema, which is exactly what happened on 2026-08-24 and cost a
confusing round of "the migration ran but the specs still fail".

Related: Z-315 (storage accounting), Z-316/Z-317 (schema drift, both applied
2026-08-24), Z-318 (patch-export outbox path).
<!-- SECTION:NOTES:END -->
