---
id: Z-069
title: 'Z-074: Scaffold Ruby Control Plane (Sequel & RubyLLM)'
status: Done
assignee:
  - '@gemini-cli'
created_date: '2026-05-15 03:01'
updated_date: '2026-05-15 03:12'
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
- [x] #1 Gemfile exists with sequel, pg, ruby_llm, and opentelemetry-sdk gems.
- [x] #2 lib/zdots.rb and lib/zdots/db.rb implemented for connection management.
- [x] #3 'bundle install' integrated into bin/bootstrap.
- [x] #4 Verification script to assert database connection via Sequel.
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Scaffolded the Ruby-based control plane.
- Created `Gemfile` with `sequel`, `pg`, `ruby_llm`, and `opentelemetry` dependencies.
- Implemented `Zdots` module and `Zdots::DB` connection manager using Sequel.
- Integrated `bundle install` into `bin/bootstrap`.
- Verified database connectivity and table access via `lib/zdots/verify_db.rb`.
- Successfully initialized OTel SDK within the Ruby environment.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
