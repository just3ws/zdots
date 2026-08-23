# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "securerandom"
require "zdots"
require "zdots/bus"

RSpec.describe "Message bus E2E", :integration do
  before(:all) do
    @db = Zdots.db
    # Z-310: posting now requires proving the name. issue_token! hands the
    # token back directly, unlike Bus.register_participant, which files it in
    # the real login Keychain — a side effect a spec has no business causing.
    @tokens = %w[agent-a agent-b].to_h do |n|
      [n, Zdots::Models::BusParticipant.issue_token!(n).last]
    end
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  def post_as(name, channel, body, thread: nil)
    Zdots::Bus.post(channel, name, body, thread: thread, token: @tokens.fetch(name))
  end

  # A uniquely-named channel per example, never a real name like "general".
  # This repo has no separate test database, so this suite runs against the
  # same tables real channels/messages live in. Two independent risks if a
  # test used a real channel name: (1) colliding with real rows even inside
  # a rolled-back transaction — a prior version of this spec wiped the tables
  # outright with an unscoped DELETE; (2) `Bus.post` publishes to Redis
  # *outside* the DB transaction (Redis has no transactional coupling to
  # Postgres), so even a rolled-back test still broadcasts to any live
  # watcher subscribed to that channel name — which then crashes trying to
  # mark a now-nonexistent (rolled-back) message as read. A unique name per
  # example sidesteps both: nothing real is at that name, and nothing
  # subscribes to `zdots:bus:<random>`.
  # Not wrapped in one outer transaction: Postgres freezes CURRENT_TIMESTAMP
  # for the lifetime of a transaction, so every row created inside a single
  # wrapping transaction gets an identical created_at — which silently broke
  # the unread query's `created_at > cursor` comparison in an earlier version
  # of this spec. Each `Bus.post` call runs in its own natural transaction
  # here, exactly like real usage, so timestamps advance normally. Isolation
  # instead comes from the unique per-example channel name: cleanup below is
  # scoped to that prefix, so it can never touch a real channel.
  let(:channel) { "spec-bus-e2e-#{SecureRandom.hex(4)}" }

  after do
    ids = Zdots.db[:bus_channels].where(Sequel.like(:name, "spec-bus-e2e-%")).select_map(:id)
    next if ids.empty?

    Zdots.db[:bus_channel_members].where(channel_id: ids).delete
    Zdots.db[:bus_messages].where(channel_id: ids).delete
    Zdots.db[:bus_channels].where(id: ids).delete
  end

  it "creates a channel idempotently" do
    c1 = Zdots::Bus.create_channel(channel, topic: "test channel")
    c2 = Zdots::Bus.create_channel(channel, topic: "ignored on repeat")

    expect(c1.id).to eq(c2.id)
    expect(c1.topic).to eq("test channel")
  end

  it "round-trips post + read, oldest first" do
    Zdots::Bus.create_channel(channel)

    post_as("agent-a", channel, "first")
    post_as("agent-b", channel, "second")

    msgs = Zdots::Bus.read(channel)
    expect(msgs.map(&:body)).to eq(%w[first second])
    expect(Zdots::Bus.participant_name(msgs.first.participant_id)).to eq("agent-a")
  end

  it "threads a reply under its root and scopes --thread reads to root+replies" do
    Zdots::Bus.create_channel(channel)

    root = post_as("agent-a", channel, "root message")
    post_as("agent-b", channel, "unrelated top-level")
    reply = post_as("agent-b", channel, "a reply", thread: root.id)

    expect(reply.thread_root?).to be false
    expect(root.thread_root?).to be true

    scoped = Zdots::Bus.read(channel, thread: root.id)
    expect(scoped.map(&:id)).to contain_exactly(root.id, reply.id)
  end

  it "tracks unread per participant and a poster never sees their own message as unread" do
    Zdots::Bus.create_channel(channel)

    post_as("agent-a", channel, "hello")
    expect(Zdots::Bus.unread(channel, "agent-a")).to be_empty

    unread_for_b = Zdots::Bus.unread(channel, "agent-b")
    expect(unread_for_b.map(&:body)).to eq(["hello"])

    Zdots::Bus.mark_read(channel, "agent-b", unread_for_b.last.id)
    expect(Zdots::Bus.unread(channel, "agent-b")).to be_empty

    post_as("agent-a", channel, "second message")
    expect(Zdots::Bus.unread(channel, "agent-b").map(&:body)).to eq(["second message"])
  end

  it "raises a clean error (not a stack trace) for an unknown channel" do
    expect { Zdots::Bus.post("no-such-channel-#{SecureRandom.hex(4)}", "agent-a", "hi") }
      .to raise_error(Zdots::Models::BusChannel::NotFound, /no such bus channel/)
  end
end
