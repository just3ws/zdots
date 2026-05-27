---
id: Z-106
title: >-
  [agent-issue] lib/cognitive-load.bash missing — conf.d/05-observability.zsh
  sources it for Calm Mode frustration detection but the file does not exist;
  the feature silently does nothing. Either implement or remove the dead hook.
status: Done
assignee: []
created_date: '2026-05-27 14:31'
updated_date: '2026-05-27 16:52'
labels:
  - agent-reported
  - bug
dependencies: []
modified_files:
  - conf.d/05-observability.zsh
priority: medium
ordinal: 4890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `1f303288367406ef493f7c3500d95703`

lib/cognitive-load.bash missing — conf.d/05-observability.zsh sources it for Calm Mode frustration detection but the file does not exist; the feature silently does nothing. Either implement or remove the dead hook.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed the dead Calm Mode hook from conf.d/05-observability.zsh. The cognitive-load.bash library was removed in Z-058 and never reimplemented. The hook was silently a no-op (guarded on file existence), but the dead counter increment and conditional block were removed for clarity. Implement via Z-103 when error-velocity data source exists in zdots-ctx.
<!-- SECTION:FINAL_SUMMARY:END -->
