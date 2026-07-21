---
id: Z-162
title: 'context-engine: port spec suite from ActiveRecord to Sequel idioms'
status: In Progress
assignee: []
created_date: '2026-06-20 03:33'
updated_date: '2026-07-21 21:39'
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
Phase 2 (my@3c2be7e + zdots migration 20260721000000): Z-241 columns migrated (my + my_test); resolver singular-alias bug fixed (every policy query 500'd in prod); spec /v1->/api/v1 rot swept. Suite 58->22. Remaining: 5 prime_and_reprocess Open3-mock (home WIP), 1 dashboard cockpit (home WIP), ~4 clusters: gaps_controller 'if gap.save' assumes AR false-on-invalid but Sequel raises (unreachable 422 branch), an 'AND requires 1 argument' validation issue, policy_rule model validations, parity leftovers.
<!-- SECTION:NOTES:END -->
