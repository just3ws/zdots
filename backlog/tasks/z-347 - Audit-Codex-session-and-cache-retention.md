---
id: Z-347
title: Audit Codex session and cache retention
status: Done
assignee: []
created_date: 2026-10-20 15:37
updated_date: '2026-10-31T23:07:00Z'
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
Metadata-only audit completed on 2026-10-31. Codex CLI 0.166.0 resumes saved sessions by ID or picker; the official CLI reference says archive/unarchive only hide/restore sessions in the picker without deleting transcripts. The 1.5 GiB session store and 8.1 MiB SQLite state remain untouched. Codex occupies 3.5 GiB total. The only low-risk cleanup candidate is the 61 MiB `~/.codex/cache` subtree, but no documented cache-clear operation was found and the recovery is marginal against the recording reserve; no cache was removed. Temporary backups and the previous app-server release remain because their cleanup/restore semantics are unclear.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Inventory current Codex state by top-level size using metadata only; classify user history, active runtime packages, plugins, and regenerable cache.
- [x] #2 Verify current Codex session discovery/resume and retention behavior from authoritative local or official documentation before moving or compressing sessions.
- [x] #3 Preserve session files and SQLite databases; any cold archive must include a manifest, checksums, and a demonstrated restore path before originals can be removed.
- [x] #4 Document safe cache-only cleanup targets and expected storage recovery; leave ambiguous paths untouched.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 All related changes committed — git status clean for files touched by this task
- [x] #3 Session/cache inventory and the Codex CLI resume/archive semantics are recorded; no history or database files were read or removed.
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31 metadata-only inventory: ~/.codex totals 3.5 GiB. `sessions`=1.5 GiB (366 JSONL files plus one other file; mtimes Feb 28–Oct 31 2026; no file contents read); `sqlite`=8.1 MiB; `archived_sessions`=1 MiB. `packages/app-server-daemon`=747 MiB split between current 0.166.0 (407 MiB) and previous 0.165.0 (340 MiB). `plugins`=396 MiB (plugin-appserver 316 MiB, plugin cache 79 MiB); computer-use app=73 MiB; `.tmp`=165 MiB, including bundled marketplace 50 MiB, plugin temp 77 MiB, old plugin backups 37 MiB + 272 KiB and legacy runtime skills. `cache`=61 MiB (remote_plugin_catalog 55 MiB, codex_app_directory 5.6 MiB, codex_apps_tools 0.8 MiB). No session, SQLite state, runtime package, plugin, or temp path changed.

OpenAI official CLI reference: `codex resume [SESSION_ID]`, `codex archive <SESSION>`, and `codex unarchive <SESSION>` are supported; archive/unarchive only hide/restore a saved session in the picker without deleting its transcript. Source: https://learn.chatgpt.com/docs/cli/reference (local Codex CLI 0.166.0 help confirms these commands). No official retention or cache purge policy was found. `~/.codex/cache` is the only low-risk cache-only candidate at ~61 MiB; expected recovery is minor against 52 GiB free and the 45 GiB recording reserve. No official cache-clear command was found, so no deletion was made. The `.tmp` tree and prior 340 MiB app-server release may have backup/runtime roles that are not established; preserve until cleanup and restore behavior are verified.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Completed a metadata-only Codex footprint audit. Codex CLI 0.166.0 supports resume/archive/unarchive; official docs state archive only hides sessions from the picker and preserves transcripts. Preserved all session JSONL files, SQLite state, app-server releases, plugins, and ambiguous temporary directories. The only candidate cache recovery is ~61 MiB, too small to materially affect the 45 GiB recording reserve; no deletion was made. Session contents and database contents were not read.
<!-- SECTION:FINAL_SUMMARY:END -->
