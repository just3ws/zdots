Sequel.migration do
  up do
    unless schema(:media_sources).map(&:first).include?(:primer_text)
      add_column :media_sources, :primer_text, String, text: true
    end
  end

  down do
    if schema(:media_sources).map(&:first).include?(:primer_text)
      drop_column :media_sources, :primer_text
    end
  end
end
