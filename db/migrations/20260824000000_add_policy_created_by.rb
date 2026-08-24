# Z-316: the propose half of the policy audit trail. Z-241 added approved_by to
# both tables but missed created_by, so PoliciesController#propose raised
# NoMethodError and every REST policy proposal returned 500.
Sequel.migration do
  up do
    cols = ->(table) { schema(table).map(&:first) }

    unless cols[:policy_documents].include?(:created_by)
      add_column :policy_documents, :created_by, String
    end
    unless cols[:policy_versions].include?(:created_by)
      add_column :policy_versions, :created_by, String
    end
  end

  down do
    cols = ->(table) { schema(table).map(&:first) }

    drop_column :policy_documents, :created_by if cols[:policy_documents].include?(:created_by)
    drop_column :policy_versions, :created_by if cols[:policy_versions].include?(:created_by)
  end
end
