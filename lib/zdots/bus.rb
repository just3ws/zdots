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

    # #tag and @mention extraction from a message body. Lookbehind excludes
    # only genuinely mid-word hits (an email's "user@domain", a CSS
    # "color:#fff") without requiring callers to quote or escape anything —
    # a bare "#fff" after whitespace is indistinguishable from a real tag
    # and IS extracted; this is a whitespace heuristic, not a validator.
    TAG_PATTERN = /(?<!\S)#([a-zA-Z0-9_-]+)/
    MENTION_PATTERN = /(?<!\S)@([a-zA-Z0-9_-]+)/

    class << self
      def create_channel(name, topic: nil, protocol: nil)
        Models::BusChannel.find_or_create(name: name) { |c| c.topic = topic; c.protocol = protocol }
      end

      # Set/update the engagement protocol on an existing channel — separate
      # from create_channel so it can retrofit a channel that already exists
      # (general, job-leads) without disturbing its topic.
      def set_protocol(name, protocol)
        channel = Models::BusChannel.resolve(name)
        channel.update(protocol: protocol)
        channel
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
      #
      # type: an optional freeform message kind (STATUS/PROPOSAL/CORRECTION/
      # QUESTION/ACK, or anything a caller picks) stored in metadata rather
      # than parsed from body text — the ad-hoc "PROPOSAL_FROM_X:" prefixes
      # agents were already inventing in body text, formalized into one field.
      def post(channel_name, participant_name, body, thread: nil, token: nil, type: nil)
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
          body: body,
          metadata: extract_metadata(body, type)
        )

        # A poster shouldn't see their own message as unread.
        Models::BusChannelMember.cursor_for(channel.id, participant.id)
                                .update(last_read_message_id: msg.id)

        publish(channel_name, participant_name, msg)
        msg
      end

      # since: only messages after this message id (exclusive)
      # thread: only replies (+ the root) for this thread root id
      # tag/mention: only messages whose extracted #tag / @mention list
      # contains this value (see extract_metadata)
      # type: only messages posted with this --type (case-insensitive exact
      # match, e.g. "IDEA" — browse open ideas with type: "IDEA", then drill
      # into one with thread: <its id> for the async discussion under it)
      # query: substring search over body (ILIKE, case-insensitive)
      # newest_first: DESC instead of the default ASC (oldest first) —
      # ordering happens at the DB level so `limit` still caps at the actual
      # newest/oldest N, not a client-side reverse of whichever N came back
      def read(channel_name, since: nil, thread: nil, tag: nil, mention: nil, type: nil, query: nil, newest_first: false, limit: 100)
        channel = Models::BusChannel.resolve(channel_name)
        ds = Models::BusMessage.where(channel_id: channel.id)
        ds = ds.where(Sequel.|({ id: thread }, { parent_id: thread })) if thread
        if since
          since_row = Models::BusMessage[since]
          ds = ds.where { created_at > since_row.created_at } if since_row
        end
        ds = filter_metadata(ds, "tags", tag)
        ds = filter_metadata(ds, "mentions", mention)
        ds = filter_type(ds, type)
        # ponytail: no LIKE-wildcard escaping on query — an internal search
        # box, not a security boundary; a stray % just matches wider than
        # expected, escape if that ever actually bites someone.
        ds = ds.where(Sequel.ilike(:body, "%#{query}%")) if query && !query.empty?
        ds.order(newest_first ? Sequel.desc(:created_at) : :created_at).limit(limit).all
      end

      def unread(channel_name, participant_name, tag: nil, mention: nil, type: nil)
        channel = Models::BusChannel.resolve(channel_name)
        participant = Models::BusParticipant.resolve(participant_name)
        cursor = Models::BusChannelMember.cursor_for(channel.id, participant.id)

        ds = Models::BusMessage.where(channel_id: channel.id)
        ds = ds.where { created_at > Models::BusMessage[cursor.last_read_message_id].created_at } if cursor.last_read_message_id
        ds = filter_metadata(ds, "tags", tag)
        ds = filter_metadata(ds, "mentions", mention)
        ds = filter_type(ds, type)
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

      def format_age(seconds)
        sec = seconds.to_i
        if sec < 60
          "#{sec}s ago"
        elsif sec < 3600
          "#{sec / 60}m ago"
        elsif sec < 86400
          "#{sec / 3600}h ago"
        else
          "#{sec / 86400}d ago"
        end
      end

      def chats(participant_name = nil, filter: nil, channel_name: nil, stale_threshold_hours: 48)
        participant_name ||= ENV.fetch("ZDOTS_BUS_PARTICIPANT", "mike")
        participant = Models::BusParticipant[name: participant_name]
        now = Time.now

        target_channels = if channel_name && !channel_name.empty?
                            [Models::BusChannel.resolve(channel_name)]
                          else
                            Models::BusChannel.order(:name).all
                          end

        results = target_channels.map do |c|
          msgs = Models::BusMessage.where(channel_id: c.id).order(Sequel.desc(:created_at))
          total = msgs.count
          last_msg = msgs.first

          unreads = participant ? unread(c.name, participant_name) : []
          unread_count = unreads.size

          if total.zero?
            {
              channel: c.name,
              topic: c.topic,
              protocol: c.protocol,
              unread: 0,
              total: 0,
              status: "EMPTY",
              last_sender: "-",
              last_active: "-",
              last_active_at: nil,
              snippet: "(no messages)",
              pending_messages: [],
              is_stale: false,
              waiting_for_reply: false,
              has_unread: false,
              has_pending: false
            }
          else
            last_sender = participant_name(last_msg.participant_id)
            age_sec = (now - last_msg.created_at).to_i
            last_active = format_age(age_sec)
            is_stale = age_sec >= (stale_threshold_hours * 3600)
            type = last_msg.metadata["type"]
            body_clean = last_msg.body.gsub(/\s+/, " ").strip[0..50]
            snippet = type ? "[#{type}] #{body_clean}" : body_clean

            has_mention = unreads.any? do |m|
              (m.metadata["mentions"] || []).map(&:downcase).include?(participant_name.downcase)
            end

            has_question = unreads.any? do |m|
              m.metadata["type"]&.upcase == "QUESTION" || m.body.strip.end_with?("?")
            end

            last_from_peer = (last_sender != participant_name && last_sender != "pipeline")

            status = if has_mention
                       "MENTIONED"
                     elsif has_question && last_from_peer
                       "QUESTION"
                     elsif last_from_peer && (type == "QUESTION" || last_msg.body.strip.end_with?("?"))
                       "WAITING_REPLY"
                     elsif last_from_peer && unread_count.positive?
                       "NEEDS_REPLY"
                     elsif last_sender == participant_name
                       "REPLIED"
                     elsif unread_count.positive?
                       "UNREAD"
                     elsif is_stale
                       "STALE"
                     else
                       "IDLE"
                     end

            pending_items = []
            unreads.each do |um|
              um_sender = participant_name(um.participant_id)
              um_type = um.metadata["type"]
              um_mentions = (um.metadata["mentions"] || []).map(&:downcase)
              is_m = um_mentions.include?(participant_name.downcase)
              is_q = um_type&.upcase == "QUESTION" || um.body.strip.end_with?("?")

              reason = if is_m then "mention"
                       elsif is_q then "question"
                       elsif um_sender != participant_name then "unread"
                       else "unread_self" end

              next if reason == "unread_self"

              pending_items << {
                id: um.id,
                parent_id: um.parent_id,
                sender: um_sender,
                body: um.body,
                type: um_type,
                created_at: um.created_at,
                age: format_age(now - um.created_at),
                reason: reason
              }
            end

            if pending_items.empty? && last_from_peer && (type == "QUESTION" || last_msg.body.strip.end_with?("?"))
              pending_items << {
                id: last_msg.id,
                parent_id: last_msg.parent_id,
                sender: last_sender,
                body: last_msg.body,
                type: type,
                created_at: last_msg.created_at,
                age: format_age(age_sec),
                reason: "question"
              }
            end

            waiting_for_reply = %w[MENTIONED QUESTION WAITING_REPLY NEEDS_REPLY].include?(status)
            has_pending = waiting_for_reply || unread_count.positive? || !pending_items.empty?

            {
              channel: c.name,
              topic: c.topic,
              protocol: c.protocol,
              unread: unread_count,
              total: total,
              status: status,
              last_sender: last_sender,
              last_active: last_active,
              last_active_at: last_msg.created_at,
              snippet: snippet,
              pending_messages: pending_items,
              is_stale: is_stale,
              waiting_for_reply: waiting_for_reply,
              has_unread: unread_count.positive?,
              has_pending: has_pending
            }
          end
        end

        sorted = results.sort_by { |r| r[:last_active_at] || Time.at(0) }.reverse

        case filter&.to_s&.downcase
        when "unread"
          sorted.select { |r| r[:has_unread] }
        when "pending"
          sorted.select { |r| r[:has_pending] }
        when "waiting", "waiting_reply", "needs_reply"
          sorted.select { |r| r[:waiting_for_reply] }
        when "stale"
          sorted.select { |r| r[:is_stale] && r[:status] != "EMPTY" }
        when nil, ""
          sorted
        else
          f = filter.to_s.downcase
          sorted.select do |r|
            r[:channel].downcase.include?(f) ||
              r[:status].downcase.include?(f) ||
              r[:last_sender].downcase.include?(f)
          end
        end
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

      def extract_metadata(body, type)
        metadata = {}
        tags = body.scan(TAG_PATTERN).flatten.uniq
        mentions = body.scan(MENTION_PATTERN).flatten.uniq
        metadata["tags"] = tags unless tags.empty?
        metadata["mentions"] = mentions unless mentions.empty?
        metadata["type"] = type if type && !type.to_s.empty?
        metadata
      end

      # jsonb array-contains-element filter (metadata->key @> ["value"]).
      # Containment (@>) rather than the jsonb `?` exists-operator: `?` is
      # also Sequel.lit's placeholder marker, so it can't appear literally in
      # the SQL string. Sequel.lit binds both args as real parameters.
      def filter_metadata(ds, key, value)
        return ds if value.nil? || value.to_s.empty?

        ds.where(Sequel.lit("metadata->? @> ?::jsonb", key, JSON.generate([value.to_s])))
      end

      # type is a scalar (not an array like tags/mentions), so this is a
      # plain text-extraction equality (->>), case-insensitive since the
      # convention is uppercase (STATUS, IDEA) but nothing enforces it.
      def filter_type(ds, value)
        return ds if value.nil? || value.to_s.empty?

        ds.where(Sequel.lit("upper(metadata->>'type') = upper(?)", value.to_s))
      end

      def publish(channel_name, participant_name, msg)
        payload = JSON.generate({
                                  id: msg.id,
                                  channel: channel_name,
                                  participant: participant_name,
                                  parent_id: msg.parent_id,
                                  body: msg.body,
                                  metadata: msg.metadata,
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
