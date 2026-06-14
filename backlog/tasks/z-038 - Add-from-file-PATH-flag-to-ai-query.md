---
id: Z-038
title: Add --from-file PATH flag to ai-query
status: To Do
assignee: []
created_date: '2026-04-19 02:32'
updated_date: '2026-06-14 18:35'
labels:
  - ai-query
  - ux
  - security
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
- [ ] #1 --from-file PATH reads the specified file as the DATA block and passes it through the same normalization and scan pipeline as stdin input,--from-file and non-tty stdin are mutually exclusive: if both are present ai-query exits 2 with a clear error message,If the specified file is not found or not readable ai-query exits 1 with a clear error message,The file basename (not full path) is included in --json output metadata,--help text and docs/ai-query.md are updated to document --from-file,Tests cover: successful file read via --from-file; mutual exclusion error with stdin; missing file error (exit 1); basename present in JSON output
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
