# Z-241: policy-engine columns the context-engine app code already uses —
# PoliciesController#approve/#rollback raise Sequel::MassAssignmentRestriction
# without them. All additive and nullable.
Sequel.migration do
  up do
    cols = ->(table) { schema(table).map(&:first) }

    unless cols[:policy_versions].include?(:content_json)
      add_column :policy_versions, :content_json, :jsonb
    end
    unless cols[:policy_versions].include?(:answer_template)
      add_column :policy_versions, :answer_template, String, text: true
    end
    unless cols[:policy_versions].include?(:change_summary)
      add_column :policy_versions, :change_summary, String, text: true
    end
    unless cols[:policy_versions].include?(:source_citations)
      add_column :policy_versions, :source_citations, :jsonb
    end
    unless cols[:policy_versions].include?(:approved_by)
      add_column :policy_versions, :approved_by, String
    end

    unless cols[:policy_documents].include?(:current_version)
      add_column :policy_documents, :current_version, Integer
    end
    unless cols[:policy_documents].include?(:approved_by)
      add_column :policy_documents, :approved_by, String
    end

    unless cols[:policy_rules].include?(:priority)
      add_column :policy_rules, :priority, Integer
    end
  end

  down do
    cols = ->(table) { schema(table).map(&:first) }

    %i[content_json answer_template change_summary source_citations approved_by].each do |c|
      drop_column :policy_versions, c if cols[:policy_versions].include?(c)
    end
    %i[current_version approved_by].each do |c|
      drop_column :policy_documents, c if cols[:policy_documents].include?(c)
    end
    drop_column :policy_rules, :priority if cols[:policy_rules].include?(:priority)
  end
end
