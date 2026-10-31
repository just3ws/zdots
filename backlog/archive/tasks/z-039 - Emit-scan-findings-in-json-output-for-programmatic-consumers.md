---
id: Z-039
title: Emit scan findings in --json output for programmatic consumers
status: Done
assignee: []
created_date: '2026-04-19 02:32'
updated_date: '2026-05-27 19:18'
labels:
  - ai-query
  - security
  - dx
dependencies: []
modified_files:
  - lib/ai-query-lib.bash
  - bin/ai-query
  - tests/ai_query.bats
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tools that call ai-query --json (CI scripts, RubyLLM integrations, agent pipelines) receive content and top-level risk metadata but not the individual scanner findings. A consumer that wants to branch on a specific finding type — for example, take different action when EXEC_COMMAND is detected vs REDIRECT_INSTEAD — cannot do so without re-implementing the scanner rules. Exposing structured findings in the JSON output closes this gap and makes ai-query a complete programmatic interface for downstream tooling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 --json output includes a findings array: each element contains weight, name, and excerpt for each scanner rule that matched,risk_score and risk_level remain at the top level of the JSON object unchanged (backward compatible),findings is an empty array [] when no scanner patterns match,All existing --json key names are preserved with no breaking changes,Tests verify: findings array is present and valid JSON on all --json invocations; findings is [] on clean input; findings is correctly populated on an injection fixture input
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `findings` array to `--json` output. Each element has `weight` (integer), `name` (rule identifier), and `excerpt` (matched text, truncated to 120 chars). Empty array `[]` when no patterns match. Fully backward-compatible — all existing keys unchanged.\n\n`_rule` in `aiq_scan` now emits `FINDING_JSON:<jq-encoded-object>` per match; same for the fence and ANSI checks. `bin/ai-query` extracts those lines from `SCAN_OUTPUT` using `{ grep || true; }` to prevent pipefail from treating grep's no-match exit as a failure, then wraps them with `jq -s '.'`. Three new tests: findings key present, findings `[]` on clean input, findings populated on injection fixture (uses `--separate-stderr` since high-risk content triggers stderr risk-scan output that bats 1.13 would otherwise mix into `$output`).
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output
- [x] #2 file path
- [x] #3 or test result)
- [x] #4 make check passes with output captured in task notes or commit message
- [x] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
