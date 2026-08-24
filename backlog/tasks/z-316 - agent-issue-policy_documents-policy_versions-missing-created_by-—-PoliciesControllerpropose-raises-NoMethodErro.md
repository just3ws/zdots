---
id: Z-316
title: >-
  [agent-issue] policy_documents/policy_versions missing created_by —
  PoliciesController#propose raises NoMethodErro
status: To Do
assignee: []
created_date: '2026-08-24 14:14'
updated_date: '2026-08-24 14:15'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 191895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

policy_documents/policy_versions missing created_by — PoliciesController#propose raises NoMethodError (500) on every proposal

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Found 2026-08-24 while clearing the context-engine suite (operator answer C1,
"do all 16"). Three of the sixteen failures reduce to this one missing column
pair, and it is a live production defect, not a stale spec.

**Symptom:** `POST /api/v1/policies/propose` raises

    NoMethodError: undefined method 'created_by' for an instance of PolicyDocument
    app/controllers/api/v1/policies_controller.rb:38

so every policy proposal through REST 500s. `PolicyVersion.create(... created_by:)`
on line 52 of the same action would fail immediately after for the same reason.

**Cause:** both tables carry `approved_by` but neither carries `created_by`:

    policy_documents: id scope_type scope_key title status created_at updated_at current_version approved_by
    policy_versions:  id policy_document_id version_number state content_markdown created_at updated_at
                      content_json answer_template change_summary source_citations approved_by

This is the same omission Z-241 fixed for the other policy-engine columns
(`db/migrations/20260721000000_add_policy_engine_columns.rb`, "columns the
context-engine app code already uses"). `created_by` was simply missed in that
pass — the approve half of the audit trail landed, the propose half did not.

**Not applied.** AGENTS.md 5 names schema mismatches as file-don't-fix, and
migrations are exactly the shared seam that section is about. Proposed
migration, following the Z-241 shape (additive, nullable, idempotent, reversible):

    # db/migrations/20260824000000_add_policy_created_by.rb
    # Z-316: the propose half of the policy audit trail. Z-241 added approved_by
    # to both tables but missed created_by, so PoliciesController#propose 500s.
    Sequel.migration do
      up do
        cols = ->(table) { schema(table).map(&:first) }
        add_column :policy_documents, :created_by, String unless cols[:policy_documents].include?(:created_by)
        add_column :policy_versions,  :created_by, String unless cols[:policy_versions].include?(:created_by)
      end

      down do
        cols = ->(table) { schema(table).map(&:first) }
        drop_column :policy_documents, :created_by if cols[:policy_documents].include?(:created_by)
        drop_column :policy_versions,  :created_by if cols[:policy_versions].include?(:created_by)
      end
    end

Apply with `zdots-ctx migrate`. The three specs that then pass are
`spec/requests/policies_lifecycle_spec.rb:15`, `:155`, and `:183` (the last
asserts the full who-proposed/who-approved trail).
<!-- SECTION:NOTES:END -->
