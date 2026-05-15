---
id: Z-072
title: 'Z-077: Implement AI Jobs via RubyLLM'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
updated_date: '2026-05-15 03:34'
labels:
  - industrialization
  - ruby
  - ai
dependencies:
  - Z-071
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate the AI-heavy jobs to RubyLLM. This ensures consistent inference patterns across the platform and allows for easier prompt versioning and context management within the Ruby framework.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 lib/zdots/jobs/embed.rb uses RubyLLM to call the local embedding endpoint.
- [x] #2 lib/zdots/jobs/distill.rb uses RubyLLM for transcript summarization.
- [x] #3 Verified end-to-end autonomous flow using the Ruby worker.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Migrated AI-heavy jobs to RubyLLM.
- Implemented `Zdots::Jobs::Distill` and `Embed` using the `ruby_llm` gem.
- The `Distill` job now uses structured chat prompts via `RubyLLM` to extract insights from transcripts.
- The `Embed` job uses the `/v1/embeddings` endpoint via `RubyLLM` to vectorize methodologies and lessons.
- Upgraded `sbin/zdots-brain` with a `query --semantic` command that uses `RubyLLM` for search term vectorization and `pgvector` for similarity matching.
- Verified end-to-end flow: `Transcription` -> `Distillation` -> `Embedding` -> `Semantic Search`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
