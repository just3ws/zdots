---
id: Z-093
title: 'zdots-quiz: expand coverage for zdash fzf binding and llama-ctl patterns'
status: Done
assignee: []
created_date: '2026-05-23 13:54'
updated_date: '2026-06-15 10:47'
labels:
  - local-ai
  - zdots-quiz
  - prompt-engineering
  - wave4
dependencies: []
references:
  - bin/zdots-quiz
  - etc/prompts/zdots-shell.md
  - etc/prompts/zdots-default.md
  - bin/zdash
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add TC-15 and TC-16 to `bin/zdots-quiz` for two currently uncovered high-frequency task types: zdash fzf key binding patterns and llama-ctl subcommand patterns. These are not covered by any system prompt and the local model will hallucinate on both.

**TC-15 shell**: "Write a new fzf key binding for zdash that runs `ztask done` on the selected task."
- Expected patterns: `--bind`, `ctrl-`, `execute`, `ztask`

**TC-16 shell**: "What llama-ctl commands install, start, and verify the local AI model?"
- Expected patterns: `llama-ctl install`, `llama-ctl start`, `llama-ctl model-verify`

**Pre-work required**: Add zdash fzf binding example to `etc/prompts/zdots-shell.md` and llama-ctl subcommand table to `etc/prompts/zdots-default.md`. Do not add until TC-15/TC-16 are written and failing (verify the gap first, then fix).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 TC-15 and TC-16 added to zdots-quiz
- [x] #2 Both cases fail before prompt additions (gap confirmed)
- [x] #3 Prompts updated minimally to pass both cases
- [x] #4 Total quiz remains < 20 cases
- [x] #5 zdots-quiz --list shows TC-15 and TC-16
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added TC-15 (zdash fzf binding) and TC-16 (llama-ctl install/start/model-verify) to zdots-quiz, gap-first: both failed pre-fix (TC-15 empty→0/4; TC-16 'status' not 'model-verify'→2/3), then minimal prompt additions (7-line zdash fzf section in zdots-shell.md; 12-line llama-ctl table in zdots-default.md) closed the gap. Quiz now 17 cases (<20); --list shows both. Latent bug fixed: grep -qiE -- (the -- end-of-options marker) so the --bind pattern isn't parsed as a grep flag. secret-scan clean. Commit 499f1e3. (sonnet worktree fan-out, diff-reviewed before merge.)
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
