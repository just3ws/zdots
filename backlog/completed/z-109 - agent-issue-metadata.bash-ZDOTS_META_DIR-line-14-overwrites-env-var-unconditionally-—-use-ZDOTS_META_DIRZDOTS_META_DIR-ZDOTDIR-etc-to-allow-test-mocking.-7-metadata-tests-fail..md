---
id: Z-109
title: >-
  [agent-issue] metadata.bash: ZDOTS_META_DIR line 14 overwrites env var
  unconditionally — use ZDOTS_META_DIR=${ZDOTS_META_DIR:-${ZDOTDIR}/etc} to
  allow test mocking. 7 metadata tests fail.
status: Done
assignee: []
created_date: '2026-05-27 15:12'
updated_date: '2026-05-27 16:08'
labels:
  - agent-reported
  - bug
dependencies: []
modified_files:
  - lib/metadata.bash
  - tests/metadata.bats
priority: medium
ordinal: 7890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `1f303288367406ef493f7c3500d95703`

metadata.bash: ZDOTS_META_DIR line 14 overwrites env var unconditionally — use ZDOTS_META_DIR=${ZDOTS_META_DIR:-${ZDOTDIR}/etc} to allow test mocking. 7 metadata tests fail.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in commit 146dd4a + tests/metadata.bats. Three-part fix: (1) ZDOTS_META_DIR guard added so env overrides survive sourcing; (2) declare -A changed to declare -gA so cache is global in bats subshell scope; (3) yq merge order corrected to server*profile so profile fields win. Test isolation fixed by unsetting ZDOTS_AI_PROFILE in setup().
<!-- SECTION:FINAL_SUMMARY:END -->
