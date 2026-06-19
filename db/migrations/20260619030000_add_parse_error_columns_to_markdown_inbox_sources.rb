Sequel.migration do
  up do
    alter_table(:markdown_inbox_sources) do
      add_column :parse_error_class,   String, size: 200
      add_column :parse_error_message, :text
    end
  end

  down do
    alter_table(:markdown_inbox_sources) do
      drop_column :parse_error_class
      drop_column :parse_error_message
    end
  end
end
