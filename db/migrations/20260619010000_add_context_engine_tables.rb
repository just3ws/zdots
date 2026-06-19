# frozen_string_literal: true

# Tables for context-engine (my/context-engine) Rails app models.
# All live in the my database alongside zdots tables.

Sequel.migration do
  up do
    # ── markdown inbox ────────────────────────────────────────────────────────
    create_table?(:markdown_inbox_sources) do
      serial :id, primary_key: true
      varchar :source_path, size: 1024, null: false, unique: true
      varchar :file_hash, size: 64, null: false
      bigint :byte_size, null: false
      timestamptz :modified_at, null: false
      varchar :parse_status, size: 20, null: false  # parsed | parse_failed
      timestamptz :last_ingested_at, null: false
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table?(:markdown_inbox_chunks) do
      serial :id, primary_key: true
      foreign_key :markdown_inbox_source_id, :markdown_inbox_sources
      varchar :source_path, size: 1024, null: false
      varchar :source_file_hash, size: 64, null: false
      timestamptz :source_modified_at, null: false
      timestamptz :source_last_ingested_at, null: false
      varchar :section, size: 50, null: false   # principle_candidates | evidence | counterexamples
      integer :chunk_index, null: false
      text :content, null: false
      varchar :content_hash, size: 64, null: false
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_markdown_chunks_source ON markdown_inbox_chunks(markdown_inbox_source_id)"
    run "CREATE INDEX IF NOT EXISTS idx_markdown_chunks_section ON markdown_inbox_chunks(section)"

    create_table?(:markdown_principle_rules) do
      serial :id, primary_key: true
      varchar :canonical_key, size: 500, null: false, unique: true
      text :statement, null: false
      text :normalized_statement, null: false
      varchar :judgment, size: 20, null: false   # required | recommended | allowed | discouraged | forbidden
      varchar :triage_status, size: 20, null: false, default: "none"  # none | conflict
      jsonb :citations, null: false, default: Sequel.lit("'[]'::jsonb")
      jsonb :source_paths, null: false, default: Sequel.lit("'[]'::jsonb")
      jsonb :conflict_judgments, null: false, default: Sequel.lit("'[]'::jsonb")
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    # ── policy engine ─────────────────────────────────────────────────────────
    create_table?(:policy_documents) do
      serial :id, primary_key: true
      varchar :scope_type, size: 100, null: false
      varchar :scope_key, size: 255, null: false
      varchar :title, size: 500, null: false
      varchar :status, size: 50, null: false, default: "draft"
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_policy_docs_scope ON policy_documents(scope_type, scope_key)"

    create_table?(:policy_versions) do
      serial :id, primary_key: true
      foreign_key :policy_document_id, :policy_documents, null: false
      integer :version_number, null: false
      varchar :state, size: 50, null: false, default: "draft"  # draft | active | archived
      text :content_markdown, null: false
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_policy_versions_doc ON policy_versions(policy_document_id)"
    run "CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_versions_doc_num ON policy_versions(policy_document_id, version_number)"

    create_table?(:policy_rules) do
      serial :id, primary_key: true
      foreign_key :policy_version_id, :policy_versions, null: false
      varchar :rule_key, size: 500, null: false
      jsonb :rule_value, default: Sequel.lit("'{}'::jsonb")
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_policy_rules_version ON policy_rules(policy_version_id)"
    run "CREATE INDEX IF NOT EXISTS idx_policy_rules_key ON policy_rules(rule_key)"

    create_table?(:policy_gaps) do
      serial :id, primary_key: true
      text :query, null: false
      varchar :reason, size: 20, null: false   # missing | ambiguous | conflict | low_confidence
      varchar :lifecycle_state, size: 20, null: false, default: "open"  # open | triaged | resolved
      varchar :priority, size: 10, null: false, default: "medium"  # low | medium | high
      timestamptz :resolved_at
      integer :resolved_by_policy_document_id
      integer :resolved_by_policy_version_id
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_policy_gaps_state ON policy_gaps(lifecycle_state)"
    run "CREATE INDEX IF NOT EXISTS idx_policy_gaps_priority ON policy_gaps(priority)"

    create_table?(:policy_resolution_events) do
      serial :id, primary_key: true
      text :question, null: false
      varchar :scope, size: 255
      varchar :response_profile, size: 50, null: false
      jsonb :applied_rules, default: Sequel.lit("'[]'::jsonb")
      jsonb :shadowed_rules, default: Sequel.lit("'[]'::jsonb")
      jsonb :citations, default: Sequel.lit("'[]'::jsonb")
      float :confidence
      varchar :status, size: 50, null: false
      text :explanation
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_resolution_events_status ON policy_resolution_events(status)"
    run "CREATE INDEX IF NOT EXISTS idx_resolution_events_created ON policy_resolution_events(created_at DESC)"

    # ── permissions ───────────────────────────────────────────────────────────
    %w[
      markdown_inbox_sources
      markdown_inbox_chunks
      markdown_principle_rules
      policy_documents
      policy_versions
      policy_rules
      policy_gaps
      policy_resolution_events
    ].each do |table|
      run "GRANT SELECT, INSERT, UPDATE ON #{table} TO zdots_rw"
      run "GRANT SELECT ON #{table} TO zdots_ro"
      run "GRANT USAGE, SELECT ON SEQUENCE #{table}_id_seq TO zdots_rw"
    end
  end

  down do
    %w[
      policy_resolution_events
      policy_gaps
      policy_rules
      policy_versions
      policy_documents
      markdown_principle_rules
      markdown_inbox_chunks
      markdown_inbox_sources
    ].each { |t| drop_table?(t.to_sym) }
  end
end
