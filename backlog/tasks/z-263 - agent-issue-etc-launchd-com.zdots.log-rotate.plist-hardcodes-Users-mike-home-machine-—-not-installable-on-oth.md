---
id: Z-263
title: >-
  [agent-issue] etc/launchd/com.zdots.log-rotate.plist hardcodes /Users/mike
  (home machine) — not installable on oth
status: Done
assignee: []
created_date: '2026-08-01T03:37:00Z'
updated_date: '2026-11-22T12:17:05Z'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Replaced hardcoded /Users/mike paths in etc/launchd/com.zdots.log-rotate.plist with __HOME__/__ZDOTDIR__/__XDG_STATE_HOME__ placeholders and added log-rotate --install-agent [--dry-run] renderer with plutil -lint validation and Bats test (ADR-0005 Phase 2).
<!-- SECTION:NOTES:END -->
