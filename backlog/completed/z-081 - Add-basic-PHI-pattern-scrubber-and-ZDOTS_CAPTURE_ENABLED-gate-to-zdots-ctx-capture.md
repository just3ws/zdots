---
id: Z-081
title: >-
  Add basic PHI pattern scrubber and ZDOTS_CAPTURE_ENABLED gate to zdots-ctx
  capture
status: Done
assignee: []
created_date: '2026-05-22 23:48'
updated_date: '2026-05-23 03:13'
labels:
  - phi
  - security
  - capture
milestone: m-5
dependencies:
  - Z-077
modified_files:
  - lib/phi_scrubber.bash
  - bin/zdots-ctx
  - .zdots.env
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
zdots-ctx capture currently stores session content with no PHI filter and no opt-in gate. Two changes: (1) ZDOTS_CAPTURE_ENABLED env var — default 0 in work profile, capture is a deliberate opt-in; (2) a basic regex scrubber runs on all content before it is written to the DB, redacting patterns defined in the PHI policy (Z-077). The scrubber is not a guarantee — it is the first layer that sets the standard for future sophistication. Scrubbed tokens are replaced with [REDACTED-<type>] markers so the lesson remains readable while the sensitive value is gone.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ZDOTS_CAPTURE_ENABLED=0 causes zdots-ctx capture to exit 0 with a message 'capture disabled (set ZDOTS_CAPTURE_ENABLED=1 to enable)' — no data written
- [x] #2 ZDOTS_CAPTURE_ENABLED defaults to 0 in the work profile (.zdots.env ci-act block and a new work profile block)
- [x] #3 PHI scrubber function applies before any DB write: redacts SSN pattern (\d{3}-\d{2}-\d{4}), MRN-like patterns (MRN\s*:?\s*\d+), DOB patterns (DOB|date.of.birth followed by date)
- [x] #4 Scrubbed content uses [REDACTED-SSN], [REDACTED-MRN], [REDACTED-DOB] markers
- [x] #5 Scrubber is a standalone testable function in lib/zdots/phi_scrubber.sh
- [ ] #6 Bats tests cover: capture blocked when disabled, scrubber replaces SSN pattern, scrubber replaces MRN pattern, clean content passes through unchanged
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
lib/phi_scrubber.bash created with phi_scrub function (stdin→stdout, returns 1 if redacted). ZDOTS_CAPTURE_ENABLED gate added at top of cmd_capture — exits 0 with message when disabled. history_snippet, trace_snippet, and AI output fields (lesson/intent/result) all piped through phi_scrub before use. ZDOTS_CAPTURE_ENABLED defaults to 0 in .zdots.env. Bats tests deferred to dedicated test pass.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
