---
id: Z-069
title: 'Z-074: Scaffold Ruby Control Plane (Sequel & RubyLLM)'
status: To Do
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
labels:
  - industrialization
  - ruby
  - postgres
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Scaffold the Ruby-based control plane. This includes creating the Gemfile with essential dependencies (Sequel, RubyLLM, OTel), setting up the library directory structure, and implementing the central database connection manager.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Gemfile exists with sequel, pg, ruby_llm, and opentelemetry-sdk gems.
- [ ] #2 lib/zdots.rb and lib/zdots/db.rb implemented for connection management.
- [ ] #3 'bundle install' integrated into bin/bootstrap.
- [ ] #4 Verification script to assert database connection via Sequel.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
