# frozen_string_literal: true

module Zdots
  # Resolve ZDOTS_DATABASE_URL with the zdots_rw password spliced in from macOS
  # Keychain (service "zdots", account ZDOTS_RW_PASSWORD). This is the Ruby twin of
  # bin/zdots-ctx's _inject_db_password, so Rails (zdots_bridge.rb) and the brain
  # (lib/zdots/db.rb) reach the database the same way the shell does.
  #
  # The password is an ephemeral key rotated via `zdots-ctx rotate-creds`. A URL that
  # already carries an explicit password, or a missing Keychain entry, is returned
  # unchanged — so behaviour under pg_hba `trust` (password ignored) is preserved and
  # this is a safe no-op until scram enforcement is turned on.
  def self.database_url
    url = ENV.fetch("ZDOTS_DATABASE_URL", "postgresql://zdots_rw@/my")
    return url if url =~ %r{://[^/@]*:[^/@]*@} # already has user:pass@

    pw = keychain_password("ZDOTS_RW_PASSWORD")
    return url if pw.nil? || pw.empty?

    url.sub("@", ":#{pw}@") # splice ":pw" before the first '@' (userinfo@host)
  end

  # account is always a hardcoded literal here, and rotate-creds passwords are hex
  # (openssl rand -hex), so neither the command nor the URL splice needs escaping.
  def self.keychain_password(account)
    return nil unless RUBY_PLATFORM.include?("darwin")

    out = `/usr/bin/security find-generic-password -s zdots -a #{account} -w 2>/dev/null`.chomp
    out.empty? ? nil : out
  rescue StandardError
    nil
  end
end
