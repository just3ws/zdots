---
id: Z-252
title: Dashboard a11y + visual-regression CI gate (Playwright)
status: To Do
assignee: []
created_date: '2026-07-24 12:51'
labels:
  - platform-dynamism
  - agent-ready
dependencies: []
priority: high
ordinal: 128895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The A11y assessment this session found undefined status pills and sub-AA contrast that had SHIPPED to my.localhost / zdots.localhost unnoticed — because nothing checks the web surfaces. The shell has bats/local-ci/doctors; the dashboards have no equivalent gate, so this class of regression recurs silently.

Add a headless gate (Playwright MCP is already wired) that runs against my.localhost + zdots.localhost:
- axe-core (or equivalent) a11y scan — fail on WCAG 2.1 AA violations (contrast, undefined roles, missing labels).
- Visual-regression snapshot of key pages (landing, transcriptions, intelligence, a docs page) — fail on unexpected pixel diff.
- Runs in local-ci; gates the ~/my work branch the same way bats gates the shell.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Headless a11y scan runs against my.localhost + zdots.localhost and fails CI on any WCAG 2.1 AA violation
- [ ] #2 Visual-regression snapshots exist for the key pages and fail on unexpected diff, with an approve/update path
- [ ] #3 Gate is invocable locally (local-ci) and documented so it runs before ~/my work-branch pushes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
