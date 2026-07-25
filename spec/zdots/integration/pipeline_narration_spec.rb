# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "securerandom"
require "zdots"
require "zdots/jobs/ingest_media"

RSpec.describe "IngestMedia bus narration", :integration do
  before(:all) do
    @db = Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  # A uniquely-named source (and therefore channel, ingest-<source_id>) per
  # example — same isolation rationale as bus_e2e_spec.rb: this repo has no
  # separate test database, so a fixed/real name could collide with live data.
  # pipeline_runs cascades from media_sources (on_delete: :cascade in
  # 20260620000000_add_transcription_pipeline_tables.rb), so deleting the
  # media_source alone is enough to clean up both.
  let(:test_id) { "narration-test-#{SecureRandom.hex(4)}" }
  let(:channel) { "ingest-#{test_id}" }

  let(:media_source) do
    Zdots::Models::MediaSource.create(
      source_type: "youtube",
      source_uri: "https://example.invalid/#{test_id}",
      source_id: test_id,
      title: "Test Source"
    )
  end

  def build_ingest
    o = Zdots::Jobs::IngestMedia.allocate
    o.instance_variable_set(:@src, media_source)
    o.instance_variable_set(:@mid, media_source.id)
    o.instance_variable_set(:@profile, "standard")
    o
  end

  after do
    Zdots.db[:media_sources].where(Sequel.like(:source_uri, "https://example.invalid/narration-test-%")).delete
    ids = Zdots.db[:bus_channels].where(Sequel.like(:name, "ingest-narration-test-%")).select_map(:id)
    next if ids.empty?

    Zdots.db[:bus_channel_members].where(channel_id: ids).delete
    Zdots.db[:bus_messages].where(channel_id: ids).delete
    Zdots.db[:bus_channels].where(id: ids).delete
  end

  it "narrate posts to the ingest's own channel as 'pipeline'" do
    o = build_ingest
    o.send(:narrate, "hello from the pipeline")

    msgs = Zdots::Bus.read(channel)
    expect(msgs.map(&:body)).to eq(["hello from the pipeline"])
    expect(Zdots::Bus.participant_name(msgs.first.participant_id)).to eq("pipeline")
  end

  it "check_directives applies skip:<stage>, acks it, and doesn't reapply on a later call" do
    o = build_ingest
    Zdots::Bus.create_channel(channel)
    Zdots::Bus.post(channel, "mike", "skip:embedded")

    o.send(:check_directives)
    expect(o.instance_variable_get(:@skip_stages)).to include("embedded")
    expect(o.send(:run_stage, "embedded")).to be_nil

    # The ack itself advances "pipeline"'s own read cursor, so a second call
    # against the same channel sees nothing new to apply.
    o2 = build_ingest
    o2.instance_variable_set(:@skip_stages, nil)
    o2.send(:check_directives)
    expect(o2.instance_variable_get(:@skip_stages)).to be_nil
  end

  it "check_directives applies profile:<name>" do
    o = build_ingest
    Zdots::Bus.create_channel(channel)
    Zdots::Bus.post(channel, "mike", "profile:fast")

    o.send(:check_directives)
    expect(o.instance_variable_get(:@profile)).to eq("fast")
  end

  it "narrates a threaded 'didn't understand' reply for an unrecognized directive" do
    o = build_ingest
    Zdots::Bus.create_channel(channel)
    q = Zdots::Bus.post(channel, "mike", "do a barrel roll")

    o.send(:check_directives)
    reply = Zdots::Bus.read(channel, thread: q.id).find { |m| m.id != q.id }
    expect(reply.body).to match(/didn't understand/)
  end

  it "narrates a stage failure with error.class only, never error.message" do
    o = build_ingest

    expect do
      o.send(:stage, "cleaned") { raise ArgumentError, "sensitive detail should not leak" }
    end.to raise_error(ArgumentError)

    failure = Zdots::Bus.read(channel).find { |m| m.body.include?("failed") }
    expect(failure.body).to include("ArgumentError")
    expect(failure.body).not_to include("sensitive detail")
  end
end
