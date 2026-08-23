# frozen_string_literal: true

require "digest"
require "securerandom"
require_relative "../db"

module Zdots
  module Models
    # A named identity in the message bus — an agent session or a human.
    # Identity is explicit (never inferred from hostname/pid) to avoid
    # silent cross-talk between concurrent sessions.
    class BusParticipant < Sequel::Model(Zdots.db[:bus_participants])
      # Raised when a post claims a name it cannot prove it owns.
      class AuthError < StandardError; end

      # Read paths only. This is find_or_create, so it MINTS the name it is
      # given — which is exactly how a two-party handshake was fabricated by a
      # single actor (Z-310). Never reach for it on the post path; posting goes
      # through authenticate! instead.
      def self.resolve(name)
        find_or_create(name: name) { |p| p.kind = "agent" }
      end

      # Issue (or re-issue) a token and return it in the clear — the only time
      # it is ever recoverable. Only the digest is stored.
      def self.issue_token!(name, kind: "agent")
        token = SecureRandom.urlsafe_base64(32)
        p = resolve(name)
        p.update(kind: kind, token_digest: digest(token))
        [p, token]
      end

      # The post-path gate: the name must already exist, must have been issued
      # a token, and the caller must present that token.
      def self.authenticate!(name, token)
        p = find(name: name)
        raise AuthError, "bus: unknown participant #{name.inspect} — run `bus-register #{name}` first" if p.nil?

        if p.token_digest.nil?
          raise AuthError, "bus: participant #{name.inspect} predates authentication — re-run `bus-register #{name}`"
        end

        raise AuthError, "bus: bad token for #{name.inspect}" unless secure_equal?(p.token_digest, digest(token.to_s))

        p
      end

      def self.digest(token)
        Digest::SHA256.hexdigest(token)
      end

      # Both operands are fixed-length hex digests, so length never leaks.
      def self.secure_equal?(a, b)
        return false unless a.bytesize == b.bytesize

        a.bytes.zip(b.bytes).reduce(0) { |acc, (x, y)| acc | (x ^ y) }.zero?
      end

      def touch_seen!
        update(last_seen_at: Time.now)
      end
    end
  end
end
