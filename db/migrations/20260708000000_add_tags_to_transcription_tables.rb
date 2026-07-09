Sequel.migration do
  up do
    extension :pg_array

    alter_table(:media_sources) do
      add_column :tags, "text[]", default: Sequel.pg_array([], :text)
    end

    alter_table(:known_terms) do
      add_column :tags, "text[]", default: Sequel.pg_array([], :text)
    end
  end

  down do
    alter_table(:known_terms) do
      drop_column :tags
    end

    alter_table(:media_sources) do
      drop_column :tags
    end
  end
end
