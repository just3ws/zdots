---
id: Z-224
title: '[agent-issue] adots git/config re-accumulates duplicate safe.directory=/app'
status: To Do
assignee: []
created_date: '2026-07-14 00:41'
labels:
  - agent-reported
  - error
dependencies: []
priority: low
ordinal: 100895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** low
**Trace ID:** `7e8e3117608948f576b5173a7969651a`

adots ~/.config/git/config keeps re-appending '[safe] directory = /app' (seen growing 1 → 60+ dupes). Reverting via the bare repo clears it but it re-pollutes within minutes, so the source is a live process, not a stale edit.

Suspected cause: a container mounts $HOME/.config/git/config and runs 'git config --add safe.directory /app' each start; --add never dedupes, so the tracked home gitconfig grows unbounded and adots status is perpetually dirty.

Impact: adots never reports clean; lines are functionally harmless but block honest platform-sync checks.

Suggested fix (adots operator, source-side): container should use an ephemeral GIT_CONFIG_GLOBAL or 'git config --global --replace-all', not --add against the mounted home gitconfig. Not fixable by reverting the work-tree.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
