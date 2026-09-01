---
id: Z-328
title: '[agent-issue] zdots-heal Gate 6: bin/ allowlist classification drift'
status: To Do
assignee: []
created_date: '2026-09-01 13:00'
labels:
  - agent-reported
  - friction
dependencies: []
priority: medium
ordinal: 203895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** friction
**Severity:** medium
**Trace ID:** `51a96ef723d9121d483864d519bd4b0b`

zdots-heal Gate 6 flags 23 bin/ commands as UNCLASSIFIED: not in .claude/settings.json Bash() allowlist and not in the EXPECTED_MISSING registry inside .claude/commands/zdots-heal.md. All 23 have man pages so they are real, documented commands. They need Layer 4 triage (/zdots-integrate): agent-facing -> add Bash(<name>:*) to settings.json; internal-only -> add to EXPECTED_MISSING. List: bootstrap, cc-home, ctx-mcp, ctx-mcp-register, embed-model-tripwire, gemini-invoke, gemini-mcp-register, llama-mcp, nginx-ctl, nginx-regen-certs, nginx-repair, o2-mcp, o2-mcp-register, zdots, zdots-github-keys, zdots-help, zdots-keychain, zdots-man-gen, zdots-ruby, zdots-server-keys, zdots-swiftbar, zdots-theme-gen, zdots-vault-doctor, zdots-watch. Heal run did not guess-classify to avoid granting unneeded Bash permissions. Also: Gate 6 orphaned-reference scan emits 4 false positives (zdots-only, zdots-side, zdots-specific, zdots-local-analyst) from matching hyphenated prose words and an agent name; consider tightening the regex or excluding .claude/agents prose.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
