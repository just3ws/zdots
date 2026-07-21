---
id: Z-162
title: 'context-engine: port spec suite from ActiveRecord to Sequel idioms'
status: In Progress
assignee: []
created_date: '2026-06-20 03:33'
updated_date: '2026-07-21 02:51'
labels: []
dependencies: []
priority: medium
ordinal: 53890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Full RSpec suite is 95 examples / 59 failures — all pre-existing, from specs written against ActiveRecord before the app migrated to Sequel. Failures use create!/save!/update!/includes and expect AR error semantics. Affected: spec/contracts/mcp_rest_parity_spec, spec/models/policy_rule_spec, spec/requests/{context_query,gaps_query,policies_lifecycle}, spec/services/context/policy_resolver_spec. Some may reveal controller-level AR usage (PolicyController). Note: fixing config/environments/test.rb (removed stale active_storage) made the suite loadable again. Operator console's 20 specs are green and unaffected.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Phase 1 landed (my@9812fae): test isolation (my_test + _test-name guards in ContextEngine::Db/rails_helper), per-example table cleanup, create!/find_by! port (45 sites), extractor pg_jsonb fix. Suite: 65→58 failures. Remainder blocked on policy-engine schema drift (Z-236) + home-side WIP specs (dashboard cockpit, prime_and_reprocess Open3 mocks). Prod spec-residue cleanup SQL handed to operator.
<!-- SECTION:NOTES:END -->
