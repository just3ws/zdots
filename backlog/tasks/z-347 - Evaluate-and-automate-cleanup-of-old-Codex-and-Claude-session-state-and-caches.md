---
id: Z-347
title: Evaluate and automate cleanup of old Codex and Claude session state and caches
status: To Do
assignee: []
created_date: '2026-10-20 15:37'
labels:
  - agent-reported
  - chore
dependencies: []
priority: medium
type: chore
ordinal: 222895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Analysis of system disk usage revealed ~3.9 GB occupied by Codex (~3.5 GB in ~/.codex) and Claude (~404 MB in ~/.claude). While `zdots-hygiene` purges `~/.cache/codex-runtimes`, persistent state in `$HOME` accumulates without expiration.

### Storage Audit (2026-10-20)

#### Codex (`~/.codex` — 3.5 GB)
- **Historical Sessions:** `1.4 GB` in `~/.codex/sessions/2026/` (Sep: 773MB, Aug: 298MB, Mar: 107MB, Jul: 101MB, Apr: 68MB, Jun: 48MB, May: 16MB, Feb: 5MB).
- **Daemon Packages:** `946 MB` in `~/.codex/packages/app-server-daemon` (bundled node runtimes/dependencies).
- **SQLite Databases:** `571 MB` total (`thread_history_1.sqlite` is 411MB, `logs_2.sqlite` is 160MB).
- **Plugins & Plugin Cache:** `368 MB` in `~/.codex/plugins/` (includes 51MB in `plugins/cache`).
- **Computer-Use Artifacts:** `73 MB` in `~/.codex/computer-use/` (169 UI screenshots/snapshots).
- **API Cache:** `35 MB` in `~/.codex/cache/`.

#### Claude Code (`~/.claude` — 404 MB)
- **Project Workspaces:** `327 MB` in `~/.claude/projects/` (workspace-specific conversation transcripts and diff states, e.g. `wwworkremote-core` 243MB, `zdots` 46MB).
- **File Edit Snapshots:** `28 MB` in `~/.claude/file-history/`.
- **Plugins & Ephemeral Caches:** `49 MB` (`plugins/`, `cache/`, `paste-cache/`, `telemetry/`).

### Recommendations
1. Add a TTL-based sweep option (e.g. `--prune-sessions 60d`) to `zdots-hygiene` or an agent-lifecycle command.
2. Evict old computer-use artifacts (`~/.codex/computer-use`).
3. Safely prune stale workspace sessions in `~/.claude/projects/` for inactive repos.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Audit ~/.codex/sessions retention policy and implement configurable zstd cold-storage compression (default: >30d)
- [ ] #2 Audit ~/.codex/computer-use screenshot artifacts and define eviction routine
- [ ] #3 Audit ~/.claude/projects/ workspace state and determine retention/eviction safety
- [ ] #4 Incorporate approved pruning actions into zdots-hygiene or dedicated agent-cache cleanup verb
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
