---
id: Z-341
title: >-
  [agent-issue] zdots-issue derives task filename from full description
  (ENAMETOOLONG)
status: To Do
assignee: []
created_date: '2026-09-03 13:32'
updated_date: '2026-09-03 13:32'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 216895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
zdots-issue builds the backlog task filename from the ENTIRE description string, not just a title. A multi-paragraph description produces a path that exceeds the filesystem limit:

  ENAMETOOLONG: name too long, open '.../backlog/tasks/z-339 - agent-issue-openobserve.log-outgrows-...-Not-blocking.-Filed-from-zdots-heal-2026-09-03..md'

## Repro
  zdots-issue --type friction --severity medium "<200+ char multi-line description>"

## Expected
Filename derived from a short slug (first line / an explicit title), description written to the task body. Same as 'backlog task create -t <title> --desc <body>'.

## Workaround used
File with a short one-line title, then 'backlog task edit Z-NNN --desc <body>'.

Filed from /zdots-heal 2026-09-03 (hit while filing Z-339).
<!-- SECTION:DESCRIPTION:END -->
