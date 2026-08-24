# Z-317: a conflict is two rows sharing a canonical_key with opposing judgments
# -- that is what triage_status='conflict' and conflict_judgments exist to
# record, and what PrincipleRuleExtractor groups on ([canonical_key, judgment]).
# The single-column UNIQUE made that unrepresentable, so any two documents
# disagreeing about one principle rolled the whole ingest back.
Sequel.migration do
  up do
    alter_table(:markdown_principle_rules) do
      drop_constraint :markdown_principle_rules_canonical_key_key, type: :unique
      add_unique_constraint %i[canonical_key judgment],
                            name: :markdown_principle_rules_canonical_key_judgment_key
    end
  end

  # Will fail if conflict rows exist -- correct, since that data cannot be
  # represented under the old constraint.
  down do
    alter_table(:markdown_principle_rules) do
      drop_constraint :markdown_principle_rules_canonical_key_judgment_key, type: :unique
      add_unique_constraint :canonical_key, name: :markdown_principle_rules_canonical_key_key
    end
  end
end
