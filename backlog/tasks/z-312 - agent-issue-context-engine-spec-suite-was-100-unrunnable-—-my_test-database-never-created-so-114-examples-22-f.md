---
id: Z-312
title: >-
  [agent-issue] context-engine spec suite was 100% unrunnable — my_test database
  never created, so 114 examples/22 f
status: To Do
assignee: []
created_date: '2026-08-22 20:05'
updated_date: '2026-08-23 18:40'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 187895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `446f549869793a94583c5f920f60268f`

context-engine spec suite was 100% unrunnable — my_test database never created, so 114 examples/22 failures were invisible; .rspec --fail-fast hid the scale

Found 2026-08-22 while verifying Z-258. `bundle exec rspec` aborted before any
example ran:

    PG::ConnectionBad: database "my_test" does not exist

`config/database.yml` and `lib/context_engine/db.rb` both resolve the test DB
from `ZDOTS_TEST_DATABASE_URL`, defaulting to `postgresql:///my_test`. Nothing
creates it, and nothing in the repo documents creating it — so on this machine
the suite has never run. Created it and applied the zdots migrations:

    createdb my_test
    ZDOTS_MIGRATION_URL="postgresql:///my_test" zdots-ctx migrate

**Result once runnable: 114 examples, 22 failures.**

Failing areas: `policy_resolver` (2), `policies_lifecycle` (3), `gap_report` (2),
`mcp_rest_parity` (4), `prime_and_reprocess` (5), `policy_rule` model (2),
`principle_rule_extractor`, `context_query`, `dashboard`, `docs`.

Several look seed-dependent rather than broken code — the resolver expects a
`testing.required` rule and gets `[]` from a freshly-migrated, unseeded database
— so the count is an upper bound on real defects, not a defect count. It needs
triage, not a blanket fix.

**Second, compounding problem:** `.rspec` carries `--fail-fast`. Even after the
DB existed, a full run reported "14 examples, 1 failure" and stopped. The suite
looked small and nearly-green when it was neither. Whatever the merits of
fail-fast interactively, it should not be the committed default for a suite
whose health nobody can otherwise see.

Related: Z-162 (porting the spec suite from ActiveRecord to Sequel idiom, In
Progress) — some of these failures are likely that work, not regressions.
Z-258 was the one symptom that had been noticed, and it was a genuine spec bug,
fixed separately in my@dfd5b2d.

Durable fix wanted: a documented/scripted test-DB setup step so this cannot be
silently unrunnable on the next machine.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Partially addressed 2026-08-23. Suite went 22 -> 16 failures. Two REAL production defects found and fixed, both in my@12077cb and my@fca5f6b: (1) POST /api/v1/gaps/report returned 500 for any scope_hint — a varchar column handed a bare Ruby Hash, which Sequel literalized as a boolean expression; the MCP path was always correct, only REST diverged, exactly what mcp_rest_parity_spec exists to catch. (2) Platform::DocsLibrary hardcoded DEFAULT_ZDOTS_ROOT to /Users/mike.hall/.config/zsh — another machine's username — so every glob matched nothing and /docs served an empty catalog with a 200 while /docs/guide/agents 404'd in production. Also fixed 8 spec call sites using ActiveRecord Model.find(id) in a Sequel app. Remaining 16 triaged: prime_and_reprocess (5, stale mocks), policy_* (8, fixtures not persisting — likely one root cause, the cluster worth chasing), dashboard (1, stale view assertion), context_query + mcp_rest_parity (2, untraced). None of the remaining 16 is a known production risk.
<!-- SECTION:NOTES:END -->
