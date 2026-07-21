---
id: Z-241
title: >-
  [agent-issue] Schema drift: policy-engine columns never migrated —
  context-engine app code + specs use columns abs
status: To Do
assignee: []
created_date: '2026-07-21 02:50'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 115895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `262025207aeb723c5f1b68236fc119cd`

Schema drift: policy-engine columns never migrated — context-engine app code + specs use columns absent from my. policy_versions needs content_json jsonb, answer_template text, change_summary text, source_citations jsonb, approved_by text; policy_documents needs current_version integer, approved_by text; policy_rules needs priority integer. PoliciesController#approve/#rollback raise Sequel::MassAssignmentRestriction in production today; 25+ specs blocked (Z-162). Suggest additive nullable columns via zdots-ctx migrate (then mirror to my_test with pg_dump --schema-only).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
