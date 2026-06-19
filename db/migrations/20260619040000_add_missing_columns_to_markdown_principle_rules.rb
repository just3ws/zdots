Sequel.migration do
  up do
    alter_table(:markdown_principle_rules) do
      add_column :source_count, Integer, null: false, default: 0
    end
  end

  down do
    alter_table(:markdown_principle_rules) do
      drop_column :source_count
    end
  end
end
