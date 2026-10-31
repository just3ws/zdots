---
id: Z-038
title: Add --from-file PATH flag to ai-query
status: Done
assignee: []
created_date: '2026-04-19 02:32'
updated_date: '2026-06-15 10:47'
labels:
  - ai-query
  - ux
  - security
  - wave2
dependencies:
  - Z-130
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Scripts and agent contexts that process files currently use shell redirection to feed content into ai-query. A dedicated --from-file flag provides a cleaner, more auditable interface: the invocation is self-documenting in logs, avoids subshell and pipe complexity in calling scripts, and enables richer metadata (the basename can be recorded without recording content). This is a common pattern for AI tooling that processes files in automation pipelines.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 --from-file PATH reads the specified file as the DATA block and passes it through the same normalization and scan pipeline as stdin input,--from-file and non-tty stdin are mutually exclusive: if both are present ai-query exits 2 with a clear error message,If the specified file is not found or not readable ai-query exits 1 with a clear error message,The file basename (not full path) is included in --json output metadata,--help text and docs/ai-query.md are updated to document --from-file,Tests cover: successful file read via --from-file; mutual exclusion error with stdin; missing file error (exit 1); basename present in JSON output
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added --from-file PATH to ai-query. File loads into RAW_TMP with the same dd size guard as stdin, then HAS_STDIN=true routes it through the identical scan→normalize→PHI-scrub→wrap pipeline (PHI gate preserved). Mutual exclusion with non-tty stdin (exit 2/AIQ_USAGE); missing/unreadable file exit 1; --json adds source_file basename only (never contents). 9 new bats tests (group M); 98/98 ai_query.bats pass on main. secret-scan clean. Commit c9a9d0f. (sonnet worktree fan-out, diff-reviewed before merge.)
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output
- [x] #2 file path
- [x] #3 or test result)
- [x] #4 make check passes with output captured in task notes or commit message
- [x] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
