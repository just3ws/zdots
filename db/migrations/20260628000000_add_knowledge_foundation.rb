# frozen_string_literal: true

# Knowledge foundation — the convergence spine (decision-009, doc-004, Z-150/Z-151).
# Five tables: the source envelope (source_document) + the concept registry
# (concept, concept_alias, concept_link, concept_tag).
#
# PK note: doc-004 specified bigserial, but every Loop table this references
# (lessons, methodologies, session_residue, media_sources) is uuid. The
# polymorphic concept_tag.target_id must match them, so the whole foundation is
# uuid — reality over the spec sheet. target_id is polymorphic (lesson |
# methodology | session_residue | source_document) and therefore carries no FK;
# its type just has to cover all targets (all uuid).

Sequel.migration do
  up do
    # ── Source envelope (Z-150) ──────────────────────────────────────────────
    create_table?(:source_document) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :uri, null: false
      text :source_type, null: false            # youtube|playlist|webpage|pdf|docx|vtt|okf
      text :title
      text :checksum                            # content hash — dedupe + change detection
      jsonb :provenance, null: false, default: Sequel.lit("'{}'::jsonb")
      text :body_md                             # normalized markdown — the uniform output contract
      timestamptz :fetched_at
      timestamptz :ingested_at                  # null until distilled into the Loop
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end
    run "CREATE INDEX IF NOT EXISTS idx_source_document_checksum ON source_document(checksum)"
    run "CREATE INDEX IF NOT EXISTS idx_source_document_type ON source_document(source_type)"

    # ── Concept registry (Z-151) ─────────────────────────────────────────────
    create_table?(:concept) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :slug, null: false, unique: true     # stable id, e.g. seam, platform-service
      text :term, null: false                   # display form, e.g. "Seam"
      text :definition
      text :source_ref                           # CONTEXT.md / AGENTS.md anchor
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table?(:concept_alias) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      text :alias, null: false                  # the non-canonical word, e.g. "boundary"
      foreign_key :concept_id, :concept, type: :uuid, null: false, on_delete: :cascade
      boolean :disallowed, null: false, default: false  # true = AGENTS.md "Do NOT use" term
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
    # case-insensitive synonym lookup is the resolve contract
    run "CREATE UNIQUE INDEX IF NOT EXISTS idx_concept_alias_lower ON concept_alias (lower(alias))"

    create_table?(:concept_link) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      foreign_key :from_concept_id, :concept, type: :uuid, null: false, on_delete: :cascade
      foreign_key :to_concept_id, :concept, type: :uuid, null: false, on_delete: :cascade
      text :relation, null: false               # is-a | part-of | relates-to
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      unique %i[from_concept_id to_concept_id relation]  # no duplicate edges
    end
    run "CREATE INDEX IF NOT EXISTS idx_concept_link_from ON concept_link(from_concept_id)"
    run "CREATE INDEX IF NOT EXISTS idx_concept_link_to ON concept_link(to_concept_id)"

    # tag join — the coherence: ingested/distilled rows tagged with canonical concepts.
    # target_id is polymorphic (no FK); composite unique is the dedup.
    create_table?(:concept_tag) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      foreign_key :concept_id, :concept, type: :uuid, null: false, on_delete: :cascade
      text :target_kind, null: false           # source_document|lesson|methodology|session_residue
      uuid :target_id, null: false
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      unique %i[concept_id target_kind target_id]
    end
    run "CREATE INDEX IF NOT EXISTS idx_concept_tag_target ON concept_tag(target_kind, target_id)"

    # ── Grants (mirror known_terms; rw also needs DELETE for alias/link edits) ─
    %i[source_document concept concept_alias concept_link concept_tag].each do |t|
      run "GRANT SELECT, INSERT, UPDATE, DELETE ON #{t} TO zdots_rw"
      run "GRANT SELECT ON #{t} TO zdots_ro"
    end
  end

  down do
    # reverse-FK order: dependents of concept first, then concept; envelope last
    drop_table?(:concept_tag)
    drop_table?(:concept_link)
    drop_table?(:concept_alias)
    drop_table?(:concept)
    drop_table?(:source_document)
  end
end
