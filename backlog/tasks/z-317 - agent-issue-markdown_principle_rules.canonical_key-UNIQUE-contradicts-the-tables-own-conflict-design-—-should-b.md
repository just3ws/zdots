---
id: Z-317
title: >-
  [agent-issue] markdown_principle_rules.canonical_key UNIQUE contradicts the
  table's own conflict design — should b
status: To Do
assignee: []
created_date: '2026-08-24 14:31'
updated_date: '2026-08-24 14:31'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 192895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `446f549869793a94583c5f920f60268f`

markdown_principle_rules.canonical_key UNIQUE contradicts the table's own conflict design — should be UNIQUE(canonical_key, judgment)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Found 2026-08-24 clearing the context-engine suite (operator answer C1).
One failure, but it is a schema/design contradiction rather than a stale spec.

**Symptom:** `spec/services/context/principle_rule_extractor_spec.rb:8` dies with

    Sequel::UniqueConstraintViolation: PG::UniqueViolation
      duplicate key value violates unique constraint "markdown_principle_rules_canonical_key_key"
      Key (canonical_key)=(principle.run_full_check_pipeline_before_merging.9b9f404036) already exists

**The contradiction.** `db/migrations/20260619010000_add_context_engine_tables.rb:41`
declares:

    varchar :canonical_key, size: 500, null: false, unique: true

but the very same table declares the columns that only make sense if one
canonical_key can have several rows:

    varchar :triage_status, ... # none | conflict
    jsonb   :conflict_judgments, ...

and the extractor groups on the pair, not the key alone
(`app/services/context/principle_rule_extractor.rb:88`):

    grouped = candidates.group_by { |c| [ c[:canonical_key], c[:judgment] ] }

The spec states the intended contract outright — a conflict is two coexisting
contradictory rows, not a collapsed one:

    expect(pipeline_required.canonical_key).to eq(pipeline_forbidden.canonical_key)
    expect(pipeline_required.triage_status).to eq("conflict")
    expect(pipeline_forbidden.triage_status).to eq("conflict")

and it reads them back with `order(:canonical_key, :judgment)`. So
(canonical_key, judgment) is the natural key and the single-column UNIQUE is
the outlier. Real effect: the moment two ingested documents give contradictory
guidance on the same principle — exactly the case this table was built to
triage — the whole ingest transaction rolls back.

**Deliberately not "fixed" in the app.** Collapsing to one row per
canonical_key would make the spec pass while destroying the conflict-detection
feature, i.e. changing the check to match the bug.

**Not applied** (AGENTS.md 5). Proposed migration:

    # db/migrations/20260824010000_fix_principle_rule_unique_key.rb
    # Z-317: a conflict is two rows sharing a canonical_key with opposing
    # judgments. The single-column UNIQUE made that unrepresentable.
    Sequel.migration do
      up do
        alter_table(:markdown_principle_rules) do
          drop_constraint :markdown_principle_rules_canonical_key_key, type: :unique
          add_unique_constraint %i[canonical_key judgment],
            name: :markdown_principle_rules_canonical_key_judgment_key
        end
      end

      down do
        alter_table(:markdown_principle_rules) do
          drop_constraint :markdown_principle_rules_canonical_key_judgment_key, type: :unique
          add_unique_constraint :canonical_key, name: :markdown_principle_rules_canonical_key_key
        end
      end
    end

Note the down migration will fail if conflict rows exist — correct, since that
data cannot be represented under the old constraint.
<!-- SECTION:NOTES:END -->
