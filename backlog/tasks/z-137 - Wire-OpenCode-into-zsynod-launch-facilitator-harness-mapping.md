---
id: Z-137
title: Wire OpenCode into zsynod launch (facilitator harness mapping)
status: To Do
assignee: []
created_date: '2026-06-08 13:42'
labels:
  - zsynod
  - agent-ready
dependencies: []
references:
  - bin/zsynod
  - functions/enabled/_zsynod
  - tests/zsynod_launch.bats
priority: medium
ordinal: 28890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When OpenCode joins the synod roster, `zsynod launch` cannot drive it: `_launch_cmd` and `_launch_harness_json` in `bin/zsynod` have no OpenCode branch, so its launch command and session-resume wiring are undefined.

Add OpenCode support analogous to the existing seats:
- `_launch_cmd`: map `opencode` → its CLI command.
- `_launch_harness_json`: define OpenCode's session mode (named session / session-id / unsupported-create), launch args, and `resume_supported` flag, based on what the OpenCode CLI actually exposes (`--help`).

Decision required: OpenCode is not a frontier platform, and `launch` currently requires an explicit frontier facilitator (rejects local/non-frontier seats). Decide whether OpenCode is ever a valid facilitator. If not, leave the launch guard as-is — OpenCode participates as a member but never facilitates — and document that. If it should facilitate, the frontier guard needs an explicit exception.

Context: the work synod roster is Claude / Aider / Pi / soon OpenCode, with Claude the only frontier seat. The `codex`/`gemini` branches added in the launch feature are inert at work (those CLIs are absent there).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 _launch_cmd maps opencode to its CLI command
- [ ] #2 _launch_harness_json defines OpenCode session mode, launch_args, and resume_supported based on the actual OpenCode CLI --help
- [ ] #3 A decision is recorded on whether OpenCode may facilitate a launch session; the frontier guard is updated or documented accordingly
- [ ] #4 tests/zsynod_launch.bats covers the OpenCode path (launch and/or rejection, matching the facilitator decision)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
