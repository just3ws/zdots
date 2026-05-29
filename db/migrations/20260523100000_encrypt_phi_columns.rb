# frozen_string_literal: true

# Migration: encrypt PHI-sensitive text columns using pgcrypto symmetric encryption.
#
# Columns encrypted:
#   lessons.content            → content_enc (bytea)
#   methodologies.content      → content_enc (bytea)
#   session_residue.summary    → summary_enc (bytea)
#   session_residue.intent     → intent_enc  (bytea)
#   session_residue.result     → result_enc  (bytea)
#
# Key source: ZDOTS_DB_ENCRYPTION_KEY environment variable (from Keychain via .zdots.secrets).
# Generate: openssl rand -hex 32
# Store:    zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>
#
# This migration REQUIRES ZDOTS_DB_ENCRYPTION_KEY to be set. It will abort
# if the key is missing rather than leave data unencrypted.
#
# FTS indexes on content columns are dropped — they cannot operate on bytea.
# Search is handled in application code via in-memory decryption + matching.

Sequel.migration do
  up do
    key = ENV.fetch("ZDOTS_DB_ENCRYPTION_KEY", nil)
    if key.nil? || key.strip.empty?
      raise <<~MSG
        ZDOTS_DB_ENCRYPTION_KEY is not set.
        Generate: openssl rand -hex 32
        Store:    zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>
        Then add to .zdots.secrets via the Keychain pattern and re-run: zdots-ctx migrate
      MSG
    end

    run "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    # ── lessons.content ──────────────────────────────────────────────────────
    unless self[:lessons].columns.include?(:content_enc)
      alter_table(:lessons) { add_column :content_enc, :bytea }
      self[:lessons].where(content_enc: nil).each do |row|
        next if row[:content].nil?

        enc = get(Sequel.function(:pgp_sym_encrypt, row[:content], key))
        self[:lessons].where(id: row[:id]).update(content_enc: enc)
      end
      run "DROP INDEX IF EXISTS lessons_search_idx"
      alter_table(:lessons) { drop_column :content }
    end

    # ── methodologies.content ─────────────────────────────────────────────────
    unless self[:methodologies].columns.include?(:content_enc)
      alter_table(:methodologies) { add_column :content_enc, :bytea }
      self[:methodologies].where(content_enc: nil).each do |row|
        next if row[:content].nil?

        enc = get(Sequel.function(:pgp_sym_encrypt, row[:content], key))
        self[:methodologies].where(id: row[:id]).update(content_enc: enc)
      end
      run "DROP INDEX IF EXISTS methodologies_search_idx"
      alter_table(:methodologies) { drop_column :content }
    end

    # ── session_residue: summary, intent, result ──────────────────────────────
    { summary: :summary_enc, intent: :intent_enc, result: :result_enc }.each do |plain, enc_col|
      next if self[:session_residue].columns.include?(enc_col)

      alter_table(:session_residue) { add_column enc_col, :bytea }
      self[:session_residue].where(enc_col => nil).each do |row|
        next if row[plain].nil?

        enc = get(Sequel.function(:pgp_sym_encrypt, row[plain], key))
        self[:session_residue].where(id: row[:id]).update(enc_col => enc)
      end
      alter_table(:session_residue) { drop_column plain }
    end
  end

  down do
    key = ENV.fetch("ZDOTS_DB_ENCRYPTION_KEY", nil)
    raise "ZDOTS_DB_ENCRYPTION_KEY required to reverse encryption migration" if key.nil? || key.strip.empty?

    # Restore lessons.content
    if self[:lessons].columns.include?(:content_enc)
      alter_table(:lessons) { add_column :content, :text }
      self[:lessons].where.not(content_enc: nil).each do |row|
        plain = get(Sequel.function(:pgp_sym_decrypt, row[:content_enc], key))
        self[:lessons].where(id: row[:id]).update(content: plain)
      end
      alter_table(:lessons) { drop_column :content_enc }
      run "CREATE INDEX IF NOT EXISTS lessons_search_idx ON lessons USING GIN (to_tsvector('english', content || ' ' || coalesce(context, '')))"
    end

    # Restore methodologies.content
    if self[:methodologies].columns.include?(:content_enc)
      alter_table(:methodologies) { add_column :content, :text }
      self[:methodologies].where.not(content_enc: nil).each do |row|
        plain = get(Sequel.function(:pgp_sym_decrypt, row[:content_enc], key))
        self[:methodologies].where(id: row[:id]).update(content: plain)
      end
      alter_table(:methodologies) { drop_column :content_enc }
      run "CREATE INDEX IF NOT EXISTS methodologies_search_idx ON methodologies USING GIN (to_tsvector('english', title || ' ' || content))"
    end

    # Restore session_residue
    { summary_enc: :summary, intent_enc: :intent, result_enc: :result }.each do |enc_col, plain|
      next unless self[:session_residue].columns.include?(enc_col)

      alter_table(:session_residue) { add_column plain, :text }
      self[:session_residue].where.not(enc_col => nil).each do |row|
        val = get(Sequel.function(:pgp_sym_decrypt, row[enc_col], key))
        self[:session_residue].where(id: row[:id]).update(plain => val)
      end
      alter_table(:session_residue) { drop_column enc_col }
    end
  end
end
