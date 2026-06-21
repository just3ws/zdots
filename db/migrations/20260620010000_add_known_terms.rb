# frozen_string_literal: true

# known_terms — the doubt loop's vocabulary (Z-167). Terms the system already
# knows (people, brands, jargon, acronyms) so it stops flagging them, plus the
# mis-hearings (aliases) whisper produces for each, so future runs auto-correct.
# local_only: identity data that must never leave the box (pairs with the
# pseudonym map). The loop self-seeds — every confirm/correct adds a row.

Sequel.migration do
  up do
    create_table?(:known_terms) do
      uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)
      varchar :canonical, size: 200, null: false, unique: true
      varchar :category, size: 20                       # person | brand | jargon | acronym
      jsonb :aliases, null: false, default: Sequel.lit("'[]'::jsonb")  # mis-hearings → auto-fix
      varchar :source, size: 20, default: "confirmed"   # seeded | confirmed
      boolean :local_only, default: true
      timestamptz :created_at, default: Sequel::CURRENT_TIMESTAMP
      timestamptz :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    run "CREATE INDEX IF NOT EXISTS idx_known_terms_category ON known_terms(category)"

    run "GRANT SELECT, INSERT, UPDATE ON known_terms TO zdots_rw"
    run "GRANT SELECT ON known_terms TO zdots_ro"
  end

  down do
    drop_table?(:known_terms)
  end
end
