# frozen_string_literal: true

require "json"
require "open3"
require_relative "db"
require_relative "models/bus_participant"
require_relative "models/bus_channel"
require_relative "models/bus_message"
require_relative "models/bus_channel_member"

module Zdots
  # Local message bus for AI-agent (and human) collaboration: channels,
  # threaded persistent messages, named participants, per-participant unread
  # cursors. Postgres is the durable source of truth; Redis pub/sub is a
  # best-effort live-delivery layer on top for whatever happens to be
  # watching when a message is posted — nothing is lost if no one is.
  module Bus
    REDIS_HOST = ENV.fetch("ZDOTS_REDIS_HOST", "127.0.0.1")
    REDIS_PORT = ENV.fetch("ZDOTS_REDIS_PORT", "6379")

    class << self
      def create_channel(name, topic: nil)
        Models::BusChannel.find_or_create(name: name) { |c| c.topic = topic }
      end

      def channels
        Models::BusChannel.order(:name).all
      end

      KEYCHAIN_SERVICE = "zdots-bus"

      # Issues a token, stores it in the login Keychain, returns the
      # participant. The token is never returned to the caller and never
      # logged — post() reads it back from the Keychain on demand.
      #
      # ponytail: Keychain is per-user, not per-process, so any local process
      # running as this user can read any participant's token. That is a real
      # ceiling and it is deliberate: the failure this closes is *minting* a
      # name (one flag, no secret), not *stealing* one. Forgery is now a
      # deliberate act instead of a typo. Per-process isolation would need a
      # broker holding the secrets, which is a much bigger cut.
      def register_participant(name, kind: "agent")
        p, token = Models::BusParticipant.issue_token!(name, kind: kind)
        store_token(name, token)
        p
      end

      def store_token(name, token)
        system("security", "add-generic-password", "-U",
               "-s", KEYCHAIN_SERVICE, "-a", name, "-w", token,
               out: File::NULL, err: File::NULL) ||
          raise("bus: could not store token for #{name.inspect} in the Keychain")
      end

      def token_for(name)
        out, _err, status = Open3.capture3("security", "find-generic-password",
                                           "-s", KEYCHAIN_SERVICE, "-a", name, "-w")
        status.success? ? out.chomp : nil
      end

      # Writes to Postgres first (source of truth), then best-effort
      # publishes to Redis for live watchers. A publish failure never loses
      # the message — it's already durably stored.
      def post(channel_name, participant_name, body, thread: nil, token: nil)
        channel = Models::BusChannel.resolve(channel_name)
        # Z-310: prove the name before writing it. token: is here so a caller
        # that already holds one (a remote agent, a test) can pass it directly;
        # everything local falls back to the Keychain.
        participant = Models::BusParticipant.authenticate!(
          participant_name, token || token_for(participant_name)
        )
        participant.touch_seen!

        msg = Models::BusMessage.create(
          channel_id: channel.id,
          participant_id: participant.id,
          parent_id: thread,
          body: body
        )

        # A poster shouldn't see their own message as unread.
        Models::BusChannelMember.cursor_for(channel.id, participant.id)
                                .update(last_read_message_id: msg.id)

        publish(channel_name, participant_name, msg)
        msg
      end

      # since: only messages after this message id (exclusive)
      # thread: only replies (+ the root) for this thread root id
      def read(channel_name, since: nil, thread: nil, limit: 100)
        channel = Models::BusChannel.resolve(channel_name)
        ds = Models::BusMessage.where(channel_id: channel.id)
        ds = ds.where(Sequel.|({ id: thread }, { parent_id: thread })) if thread
        if since
          since_row = Models::BusMessage[since]
          ds = ds.where { created_at > since_row.created_at } if since_row
        end
        ds.order(:created_at).limit(limit).all
      end

      def unread(channel_name, participant_name)
        channel = Models::BusChannel.resolve(channel_name)
        participant = Models::BusParticipant.resolve(participant_name)
        cursor = Models::BusChannelMember.cursor_for(channel.id, participant.id)

        ds = Models::BusMessage.where(channel_id: channel.id)
        ds = ds.where { created_at > Models::BusMessage[cursor.last_read_message_id].created_at } if cursor.last_read_message_id
        ds.order(:created_at).all
      end

      def mark_read(channel_name, participant_name, message_id)
        channel = Models::BusChannel.resolve(channel_name)
        participant = Models::BusParticipant.resolve(participant_name)
        cursor = Models::BusChannelMember.cursor_for(channel.id, participant.id)
        cursor.update(last_read_message_id: message_id)
      end

      def participant_name(id)
        Models::BusParticipant[id]&.name || "unknown"
      end

      # Blocks forever, yielding a Hash per message as it's published.
      # Caller (bus-watch) handles Ctrl-C / SIGINT.
      def subscribe(channel_name)
        cmd = ["redis-cli", "-h", REDIS_HOST, "-p", REDIS_PORT, "subscribe", redis_channel(channel_name)]
        Open3.popen2(*cmd) do |_in, out, _wait|
          out.each_line do |line|
            line = line.strip
            next if line.empty? || %w[subscribe message].include?(line) || line =~ /^\d+$/

            begin
              yield JSON.parse(line, symbolize_names: true)
            rescue JSON::ParserError
              next
            end
          end
        end
      end

      private

      def publish(channel_name, participant_name, msg)
        payload = JSON.generate({
                                  id: msg.id,
                                  channel: channel_name,
                                  participant: participant_name,
                                  parent_id: msg.parent_id,
                                  body: msg.body,
                                  created_at: msg.created_at.iso8601
                                })
        system("redis-cli", "-h", REDIS_HOST, "-p", REDIS_PORT, "publish", redis_channel(channel_name), payload,
               out: File::NULL, err: File::NULL)
      end

      def redis_channel(name)
        "zdots:bus:#{name}"
      end
    end
  end
end
