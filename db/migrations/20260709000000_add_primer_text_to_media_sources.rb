Sequel.migration do
  up do
    add_column :media_sources, :primer_text, String, text: true
  end

  down do
    drop_column :media_sources, :primer_text
  end
end
