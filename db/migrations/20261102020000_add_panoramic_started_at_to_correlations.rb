Sequel.migration do
  up do
    alter_table(:panoramic_correlations) do
      add_column :panoramic_started_at, :timestamptz
    end
  end

  down do
    alter_table(:panoramic_correlations) do
      drop_column :panoramic_started_at
    end
  end
end
