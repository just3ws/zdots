---
id: Z-264
title: 'CLI fluency: ''zdots help <cmd>'' router verb + _zdots completion'
status: To Do
assignee: []
created_date: '2026-08-01 09:56'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: high
ordinal: 140895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Man coverage is 100% (103 man1, docs-contract enforced) and every --help is indexed as tooling:<name>, but there is no unified entry point: 'zdots help zsvc' hits the noun-miss logger, and functions/enabled/ has no _zdots so 'zdots <TAB>' completes nothing — undermining the dispatcher as the discoverability spine (decision-008/Z-149).

Fix: bin/zdots-help — man page if present, else <cmd> --help, else zdots-ctx query tooling:<cmd>; plus _zdots completion listing nouns from bin/zdots-* with one-liners from man NAME lines. Two small files, no new source of truth. (2026-08-01 system audit, cliux)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
