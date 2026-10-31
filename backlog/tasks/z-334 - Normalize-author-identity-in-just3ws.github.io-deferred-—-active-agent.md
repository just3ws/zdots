---
id: Z-334
title: Normalize author identity in just3ws.github.io (deferred — active agent)
status: To Do
assignee: []
created_date: 2026-09-01 20:59
updated_date: '2026-10-31T21:49:00Z'
labels:
  - agent-reported
dependencies: []
priority: low
ordinal: 209895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Audit just3ws.github.io commit identities before changing attribution. Add a .mailmap entry only for an account-specific GitHub noreply address confirmed to belong to Mike Hall <mike@just3ws.com>. Do not map employer, generic GitHub, .local, or .lan identities. Do not infer that every historical identity belongs to Mike; preserve distinct automation authors. No history rewrite or force-push.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Historical identities in scope are audited against repository history.
- [ ] #2 Only the confirmed account-specific GitHub noreply identity may map to Mike Hall <mike@just3ws.com>; no employer, generic GitHub, .local, or .lan identity is mapped.
- [ ] #3 No history rewrite or force-push; coordinate any repository change with current work in that repo.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
