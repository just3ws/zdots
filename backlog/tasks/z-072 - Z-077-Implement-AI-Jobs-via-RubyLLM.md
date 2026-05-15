---
id: Z-072
title: 'Z-077: Implement AI Jobs via RubyLLM'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
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
- [ ] #1 lib/zdots/jobs/embed.rb uses RubyLLM to call the local embedding endpoint.
- [ ] #2 lib/zdots/jobs/distill.rb uses RubyLLM for transcript summarization.
- [ ] #3 Verified end-to-end autonomous flow using the Ruby worker.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
