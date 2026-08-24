# Z-316 follow-on: the third column in the same Z-241 omission. The policy
# propose API accepts a per-rule `conditions` object (PoliciesController#propose
# line 63, parsed at line 142) but policy_rules has no such column, so
# PolicyRule.create raised Sequel::MassAssignmentRestriction and the proposal
# 500'd -- the exact failure mode Z-241's own comment describes.
#
# jsonb to match rule_value; nothing reads it yet, it is accepted and stored.
Sequel.migration do
  up do
    cols = ->(table) { schema(table).map(&:first) }

    unless cols[:policy_rules].include?(:conditions)
      add_column :policy_rules, :conditions, :jsonb, default: Sequel.lit("'{}'::jsonb")
    end
  end

  down do
    cols = ->(table) { schema(table).map(&:first) }

    drop_column :policy_rules, :conditions if cols[:policy_rules].include?(:conditions)
  end
end
