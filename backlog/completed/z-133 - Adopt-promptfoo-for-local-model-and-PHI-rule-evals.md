---
id: Z-133
title: Adopt promptfoo for local-model and PHI-rule evals
status: Done
assignee: []
created_date: '2026-06-06 00:10'
updated_date: '2026-06-22 18:26'
labels:
  - ai-tooling
  - testing
  - agent-ready
  - wave1
dependencies: []
priority: low
ordinal: 24890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
"Unit testing for LLMs." Use promptfoo to run automated evals against the local llama.cpp endpoint — e.g. does Qwen3-14B follow the PHI Operating Mode rules better than smaller models, and how do thinking vs non-thinking modes compare. Must stay local-only (point at http://127.0.0.1:11500; configure no cloud providers).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Install promptfoo and confirm it can target the local llama.cpp OpenAI-compatible endpoint
- [x] #2 Author an initial eval suite covering PHI-rule adherence and thinking vs non-thinking output
- [x] #3 No cloud providers configured — evals run entirely against local endpoints
- [x] #4 Document usage (where evals live, how to run)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Serves as Station 1 (the eval 'ruler') of the AI-stack evaluation itinerary epic Z-172. Z-172.04 (retrieval) and Z-172.05 (inference) depend on this harness to measure improvement.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Local-only promptfoo eval suite. bin/zdots-eval wrapper enforces a loopback/RFC-1918 locality guard (fails closed) then runs 'npx promptfoo eval' (no global install). etc/evals/promptfoo/promptfooconfig.yaml: 2 providers, BOTH http://127.0.0.1:11500 (no cloud provider, no real keys — apiKey dummy 'zdots-local'); 10 cases (PHI-01..06 + MODE-01..04 think/no-think). results/ gitignored (PHI hygiene). docs/evals.md documents location + run. Live run 28/32 (87.5%); the 4 failures (PHI-04 credential echo, PHI-06 multi-field, both modes) are an intentional FINDING: Qwen3-8B ignores PHI-refusal for credential/multi-field input → confirms lib/phi_scrubber.bash pre-processing is load-bearing; model-layer compliance alone is insufficient. PHI fixtures synthetic (fake SSN 123-45-6789 etc). secret-scan OK. Commit 9e8484b. (sonnet worktree fan-out, diff-reviewed; security gate audited — zero cloud providers.)
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
