---
id: Z-258
title: '[agent-issue] health_spec fails: /health returns HTML not JSON'
status: Done
assignee: []
created_date: '2026-07-24 14:01'
labels:
  - context-engine
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 134895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
spec/requests/health_spec.rb ('returns timezone metadata for sanity checks') fails: GET /health returns an HTML document (JSON.parse chokes on '<!DOCTYPE' at line 1). Expected a JSON body with status + timezone metadata.

Pre-existing — reproduced on the loofah 2.25.1 lock before the Z-256 sanitizer bump, so not introduced by it. Likely a routing/format regression (health action rendering HTML, or an error page) in the test env. Fix the /health action/route to render JSON, or update the spec if the contract changed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GET /health returns application/json with status=ok and the timezone metadata keys the spec asserts
- [ ] #2 spec/requests/health_spec.rb passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
