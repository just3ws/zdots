# frozen_string_literal: true

# Revoke PUBLIC execute on pgp_sym_decrypt / pgp_sym_decrypt_bytea.
#
# By default, PostgreSQL grants EXECUTE on all functions to PUBLIC. This means
# zdots_ro (SELECT-only) can call pgp_sym_decrypt and attempt decryption with
# any key it guesses. Restricting to zdots_writer (the app user) closes this:
# even with a stolen zdots_ro credential + a guessed key, decryption fails at
# the function-permission level before any crypto attempt is made.
#
# zdots_writer inherits from zdots_rw. zdots_rw (the app user) already has
# EXECUTE on all functions via the writer role in the access roles migration.
#
# pgp_sym_encrypt / pgp_sym_encrypt_bytea are also restricted — a read-only
# user has no legitimate reason to encrypt new data.

Sequel.migration do
  up do
    %w[
      pgp_sym_decrypt(bytea,text)
      pgp_sym_decrypt(bytea,text,text)
      pgp_sym_decrypt_bytea(bytea,text)
      pgp_sym_decrypt_bytea(bytea,text,text)
      pgp_sym_encrypt(text,text)
      pgp_sym_encrypt(text,text,text)
      pgp_sym_encrypt_bytea(bytea,text)
      pgp_sym_encrypt_bytea(bytea,text,text)
    ].each do |sig|
      run "REVOKE EXECUTE ON FUNCTION #{sig} FROM PUBLIC"
      run "GRANT  EXECUTE ON FUNCTION #{sig} TO zdots_writer"
    end
  end

  down do
    %w[
      pgp_sym_decrypt(bytea,text)
      pgp_sym_decrypt(bytea,text,text)
      pgp_sym_decrypt_bytea(bytea,text)
      pgp_sym_decrypt_bytea(bytea,text,text)
      pgp_sym_encrypt(text,text)
      pgp_sym_encrypt(text,text,text)
      pgp_sym_encrypt_bytea(bytea,text)
      pgp_sym_encrypt_bytea(bytea,text,text)
    ].each do |sig|
      run "GRANT EXECUTE ON FUNCTION #{sig} TO PUBLIC"
    end
  end
end
