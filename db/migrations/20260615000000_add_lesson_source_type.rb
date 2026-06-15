# frozen_string_literal: true

# Add source_type discriminator to lessons.
# Values: user | capture | ingest | distill (see LessonIntake, CONTEXT.md).
# NULL is valid for rows that pre-date this column; query logic should treat
# NULL as "unknown" rather than a missing-data error.
Sequel.migration do
  up do
    alter_table(:lessons) do
      add_column :source_type, String
    end

    run "CREATE INDEX IF NOT EXISTS lessons_source_type_idx ON lessons (source_type)"
  end

  down do
    alter_table(:lessons) do
      drop_column :source_type
    end
  end
end
