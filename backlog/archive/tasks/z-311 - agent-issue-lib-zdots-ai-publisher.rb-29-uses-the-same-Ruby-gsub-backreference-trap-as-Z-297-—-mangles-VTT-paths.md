---
id: Z-311
title: >-
  [agent-issue] lib/zdots/ai/publisher.rb:29 uses the same Ruby gsub
  backreference trap as Z-297 — mangles VTT paths
status: Done
assignee: []
created_date: '2026-08-22 18:19'
updated_date: '2026-08-23 18:40'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 186895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

lib/zdots/ai/publisher.rb:29 uses the same Ruby gsub backreference trap as Z-297 — mangles VTT paths containing an apostrophe (no shell, ffmpeg filter parser only)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed in zdots@7feebef9. Worse than the report: the string-form gsub dropped the apostrophe AND appended the post-match, so /tmp/Mike's Talk/a.vtt became /tmp/Mikes Talk/a.vtts Talk/a.vtt — ffmpeg then got a subtitles= path pointing nowhere, so any interview in a directory with an apostrophe published without subtitles. Block form fixes it. Swept lib/bin/sbin for sibling string-form replacements containing a backslash: none remain. 5 specs, verified green-red-green (reverting fails 3 of 5).
<!-- SECTION:NOTES:END -->
