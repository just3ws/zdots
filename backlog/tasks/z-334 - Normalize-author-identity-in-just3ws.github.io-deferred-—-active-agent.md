---
id: Z-334
title: Normalize author identity in just3ws.github.io (deferred — active agent)
status: To Do
assignee: []
created_date: '2026-09-01 20:59'
labels:
  - agent-reported
dependencies: []
priority: low
ordinal: 209895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
just3ws.github.io (public resume/portfolio site, custom domain www.just3ws.com, Pages deploy workflow) has 24 non-canonical author commits across master/consultancy/conversations: mike@benchprep.com x10 (2018, adding BenchPrep to the resume), mike@zalewholite.local x10 (2026-05 content audits), just3ws@users.noreply.github.com x4 (2016 CNAME/init). dependabot[bot] x1 is approved. The platform trio (zdots/vdots/adots) was fully normalized via git-filter-repo 2026-09; this repo was NOT in scope. DEFERRED: as of 2026-09-01 another agent is actively working a time-sensitive project in that repo — a history rewrite/force-push would be destructive. Also: the exposure is benign (2018 employer email on a resume site corroborates public employment history). RECOMMENDATION: do NOT rewrite; add a tracked .mailmap (same content as the platform repos' — see ~/.config/zsh/.mailmap) mapping benchprep.com / zalewholite.local / just3ws@users.noreply -> Mike Hall <mike@just3ws.com>, dependabot unmapped. Zero history change, no force-push, normalizes GitHub contributor graph + git shortlog/blame/--use-mailmap. Coordinate the single .mailmap commit with the active agent or land it once their project ships.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 just3ws.github.io has a tracked .mailmap normalizing all historical aliases to Mike Hall <mike@just3ws.com>
- [ ] #2 git shortlog --use-mailmap on that repo shows a single human author (+ dependabot[bot])
- [ ] #3 no history rewrite performed; coordinated with the agent that was mid-project
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
