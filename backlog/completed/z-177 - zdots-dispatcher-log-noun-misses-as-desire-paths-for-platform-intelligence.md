---
id: Z-177
title: 'zdots dispatcher: log noun-misses as desire paths for platform intelligence'
status: Done
assignee: []
created_date: '2026-06-28 20:43'
updated_date: '2026-06-29 02:05'
labels:
  - wave2
  - agent-ready
dependencies: []
ordinal: 73890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When bin/zdots receives an unknown noun, log it to macOS Unified Logging (logger -t zdots) so history-intelligence can surface high-frequency misses as recommended nouns to build. Follow-on: local LLM fuzzy-match suggestion in the error path ('did you mean zdots phi-scrub?'); feed noun-miss series into zdots-ctx query --semantic to surface user-intent patterns. The dispatcher's error path is the platform's appetite sensor — tried-but-missing nouns are the highest-signal user requests. See Z-149 (bin/zdots).
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
