---
id: Z-263
title: >-
  [agent-issue] etc/launchd/com.zdots.log-rotate.plist hardcodes /Users/mike
  (home machine) — not installable on oth
status: To Do
assignee: []
created_date: '2026-08-01 03:37'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 139895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `107047ff4d1f472d08c55eb975ef5db4`

etc/launchd/com.zdots.log-rotate.plist hardcodes /Users/mike (home machine) — not installable on other machines. No install step exists for it (zdots-update-local covers llama plists only). Work machine had NO log-rotate job wired until 2026-07-31 (openobserve.log hit 96M). Interim: rendered machine-local copy via sed into ~/Library/LaunchAgents. Fix: render plist at install time from a template (like llama-ctl install) and add it to zdots-update-local.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
