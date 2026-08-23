# frozen_string_literal: true

# Z-310: bus participant identity was unauthenticated. `BusParticipant.resolve`
# is find_or_create, so posting under any name minted that name — which is how a
# two-party "handshake" got fabricated by a single actor on 2026-08-22.
#
# token_digest is SHA256 of a token handed out once at registration. Posting now
# requires proving you hold it; reading does not, since reads carry no identity
# claim. Nullable because existing participants predate tokens: they can still
# be read and referenced, they just cannot post until re-registered.
Sequel.migration do
  up do
    alter_table(:bus_participants) do
      add_column :token_digest, String, size: 64
    end
  end

  down do
    alter_table(:bus_participants) { drop_column :token_digest }
  end
end
