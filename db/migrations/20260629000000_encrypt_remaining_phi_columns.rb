# frozen_string_literal: true

# Migration: encrypt remaining PHI-sensitive text columns.
#
# Columns encrypted:
#   lessons.context           → context_enc  (bytea)
#   source_document.body_md   → body_md_enc  (bytea)
#
# Key source: ZDOTS_DB_ENCRYPTION_KEY (from Keychain via .zdots.secrets)
# Audit: AC#2 of Z-101 — these were the only remaining unencrypted sensitive columns.
#   - command_runs.*: pre-scrubbed by _zca_redact, no PHI reaches the store
#   - jobs.payload: transient; completed jobs hold no patient data
#   - operational_feedback.description: platform ops data, not patient data

Sequel.migration do
  up do
    key = ENV.fetch("ZDOTS_DB_ENCRYPTION_KEY", nil)
    if key.nil? || key.strip.empty?
      raise <<~MSG
        ZDOTS_DB_ENCRYPTION_KEY is not set.
        Generate: openssl rand -hex 32
        Store:    zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>
        Then re-run: zdots-ctx migrate
      MSG
    end

    run "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    # ── lessons.context ───────────────────────────────────────────────────────
    unless self[:lessons].columns.include?(:context_enc)
      alter_table(:lessons) { add_column :context_enc, :bytea }
      self[:lessons].where(context_enc: nil).each do |row|
        next if row[:context].nil?

        enc = get(Sequel.function(:pgp_sym_encrypt, row[:context], key))
        self[:lessons].where(id: row[:id]).update(context_enc: enc)
      end
      alter_table(:lessons) { drop_column :context }
    end

    # ── source_document.body_md ───────────────────────────────────────────────
    unless self[:source_document].columns.include?(:body_md_enc)
      alter_table(:source_document) { add_column :body_md_enc, :bytea }
      self[:source_document].where(body_md_enc: nil).each do |row|
        next if row[:body_md].nil?

        enc = get(Sequel.function(:pgp_sym_encrypt, row[:body_md], key))
        self[:source_document].where(id: row[:id]).update(body_md_enc: enc)
      end
      alter_table(:source_document) { drop_column :body_md }
    end
  end

  down do
    key = ENV.fetch("ZDOTS_DB_ENCRYPTION_KEY", nil)
    raise "ZDOTS_DB_ENCRYPTION_KEY required to reverse encryption migration" if key.nil? || key.strip.empty?

    # Restore lessons.context
    if self[:lessons].columns.include?(:context_enc)
      alter_table(:lessons) { add_column :context, :text }
      self[:lessons].where.not(context_enc: nil).each do |row|
        plain = get(Sequel.function(:pgp_sym_decrypt, Sequel.blob(row[:context_enc].to_s), key))
        self[:lessons].where(id: row[:id]).update(context: plain)
      end
      alter_table(:lessons) { drop_column :context_enc }
    end

    # Restore source_document.body_md
    if self[:source_document].columns.include?(:body_md_enc)
      alter_table(:source_document) { add_column :body_md, :text }
      self[:source_document].where.not(body_md_enc: nil).each do |row|
        plain = get(Sequel.function(:pgp_sym_decrypt, Sequel.blob(row[:body_md_enc].to_s), key))
        self[:source_document].where(id: row[:id]).update(body_md: plain)
      end
      alter_table(:source_document) { drop_column :body_md_enc }
    end
  end
end
