# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:policy_gaps) do
      add_column :scope_hint, String, size: 500
      add_column :clarifying_questions, :jsonb, default: Sequel.lit("'[]'::jsonb")
    end
  end

  down do
    alter_table(:policy_gaps) do
      drop_column :scope_hint
      drop_column :clarifying_questions
    end
  end
end
