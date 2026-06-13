# frozen_string_literal: true

Sequel.migration do
  up do
    # operational_feedback table: capture issues, requests, and friction
    create_table?(:operational_feedback) do
      serial :id, primary_key: true
      varchar :report_type, size: 20, null: false  # error, request, friction
      varchar :severity, size: 20  # low, medium, high, critical
      varchar :title, size: 500, null: false
      text :description
      varchar :reporter, size: 255  # actor name (e.g., pi-agent, user-1)
      varchar :trace_id, size: 255  # link to OTEL trace
      jsonb :environment, default: Sequel.lit("'{}'::jsonb")  # machine, version, services, etc
      varchar :status, size: 50, default: "open"  # open, wontfix, fixed, duplicate
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
      column :tags, "text[]", default: Sequel.lit("'{}'::text[]")
    end

    run "CREATE INDEX IF NOT EXISTS idx_operational_feedback_type_status ON operational_feedback(report_type, status)"
    run "CREATE INDEX IF NOT EXISTS idx_operational_feedback_created ON operational_feedback(created_at DESC)"
    run "CREATE INDEX IF NOT EXISTS idx_operational_feedback_severity ON operational_feedback(severity)"

    # recommendations table: patterns and suggestions
    create_table?(:recommendations) do
      serial :id, primary_key: true
      varchar :category, size: 50  # error_cluster, feature_request, cascade, friction, performance
      varchar :pattern, size: 500
      integer :frequency  # N occurrences
      varchar :severity, size: 20
      column :affected_actors, "text[]", default: Sequel.lit("'{}'::text[]")  # list of reporters
      text :recommendation
      varchar :action, size: 100  # file_bug, add_to_backlog, improve_docs, dismiss
      float :score  # urgency × impact
      timestamptz :generated_at, default: Sequel::CURRENT_TIMESTAMP
      boolean :acted_on, default: false
      integer :related_issue_id, foreign_key: :operational_feedback
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_recommendations_score ON recommendations(score DESC)"
    run "CREATE INDEX IF NOT EXISTS idx_recommendations_category ON recommendations(category)"
    run "CREATE INDEX IF NOT EXISTS idx_recommendations_acted_on ON recommendations(acted_on)"
    run "CREATE INDEX IF NOT EXISTS idx_recommendations_related_issue ON recommendations(related_issue_id)"

    # Grant permissions to application users
    run "GRANT SELECT, INSERT, UPDATE ON operational_feedback TO zdots_rw"
    run "GRANT SELECT ON operational_feedback TO zdots_ro"
    run "GRANT USAGE, SELECT ON SEQUENCE operational_feedback_id_seq TO zdots_rw"

    run "GRANT SELECT, INSERT, UPDATE ON recommendations TO zdots_rw"
    run "GRANT SELECT ON recommendations TO zdots_ro"
    run "GRANT USAGE, SELECT ON SEQUENCE recommendations_id_seq TO zdots_rw"
  end

  down do
    drop_table?(:recommendations)
    drop_table?(:operational_feedback)
  end
end
