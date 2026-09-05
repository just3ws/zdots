# frozen_string_literal: true

require "spec_helper"
require "zdots"
require "zdots/context_bot"

# :integration because context_bot.rb pulls in the Sequel::Model classes
# (MediaSource, PipelineRun), which need a live Zdots.db connection just to
# load — same reason bus_e2e_spec.rb is tagged this way. Nothing here queries
# a real table or calls a real model/subprocess: every boundary (Bus,
# MediaSource, PipelineRun, Zdots.run_bounded) is stubbed per example.
RSpec.describe Zdots::ContextBot, :integration do
  before(:all) do
    Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  describe "glob_to_regex" do
    it "matches an exact channel name only" do
      re = described_class.send(:glob_to_regex, "general")
      expect(re).to match("general")
      expect(re).not_to match("general2")
    end

    it "matches a trailing wildcard as a prefix" do
      re = described_class.send(:glob_to_regex, "ingest-*")
      expect(re).to match("ingest-abc123")
      expect(re).not_to match("ingestfoo")
    end
  end

  describe "matching_channels" do
    it "selects channels matching any of the given patterns" do
      allow(Zdots::Bus).to receive(:channels).and_return(
        [double(name: "general"), double(name: "ingest-abc"), double(name: "random")]
      )
      expect(described_class.send(:matching_channels, ["general", "ingest-*"]))
        .to contain_exactly("general", "ingest-abc")
    end
  end

  describe "handle" do
    let(:msg) { { id: "msg-1", participant: "mike", body: "@context-engine what stage is this on?" } }

    it "never replies to its own messages" do
      expect(Zdots::Bus).not_to receive(:post)
      described_class.send(:handle, "general", msg.merge(participant: "context-engine"))
    end

    it "ignores messages without the trigger prefix" do
      expect(Zdots::Bus).not_to receive(:post)
      described_class.send(:handle, "general", msg.merge(body: "just chatting"))
    end

    it "replies to a triggered message, threaded to it" do
      allow(described_class).to receive(:answer).with("general", "what stage is this on?").and_return("stage: raw")
      expect(Zdots::Bus).to receive(:post).with("general", "context-engine", "stage: raw", thread: "msg-1")
      described_class.send(:handle, "general", msg)
    end

    it "replies with a short apology when answering raises, instead of crashing" do
      allow(described_class).to receive(:answer).and_raise(RuntimeError, "boom")
      expect(Zdots::Bus).to receive(:post)
        .with("general", "context-engine", "context-engine: couldn't answer right now", thread: "msg-1")
      described_class.send(:handle, "general", msg)
    end

    it "respects custom bot_name and bot_trigger from environment" do
      stub_const("ENV", ENV.to_hash.merge("ZDOTS_BUS_BOT_NAME" => "syntagma", "ZDOTS_BUS_BOT_TRIGGER" => "@syntagma"))
      custom_msg = { id: "msg-2", participant: "mike", body: "@syntagma status please" }
      allow(described_class).to receive(:answer).with("general", "status please").and_return("all healthy")
      expect(Zdots::Bus).to receive(:post).with("general", "syntagma", "all healthy", thread: "msg-2")
      described_class.send(:handle, "general", custom_msg)
    end
  end

  describe "source_summary_for" do
    it "returns nil for a non-ingest channel" do
      expect(described_class.send(:source_summary_for, "general")).to be_nil
    end

    it "folds in title, tags, primer_text, and stage status for an ingest channel" do
      src = double(id: "sid-1", title: "A Talk", tags: %w[ai ruby], primer_text: "a primer")
      allow(Zdots::Models::MediaSource).to receive(:first).with(source_id: "abc").and_return(src)
      run = double(stage: "raw", status: "done")
      allow(Zdots::Models::PipelineRun).to receive_message_chain(:where, :order, :all).and_return([run])

      summary = described_class.send(:source_summary_for, "ingest-abc")
      expect(summary).to include("Source: A Talk")
      expect(summary).to include("Tags: ai, ruby")
      expect(summary).to include("Primer: a primer")
      expect(summary).to include("Stages: raw=done")
    end
  end

  describe "ai_query" do
    it "retags subprocess output as UTF-8 and strips it" do
      status = double(success?: true)
      allow(Zdots).to receive(:run_bounded).and_return(["  hello  ".dup.force_encoding("US-ASCII"), status])

      out = described_class.send(:ai_query, "task", "input")
      expect(out).to eq("hello")
      expect(out.encoding).to eq(Encoding::UTF_8)
    end

    it "raises when the subprocess fails" do
      status = double(success?: false, exitstatus: 3)
      allow(Zdots).to receive(:run_bounded).and_return(["", status])

      expect { described_class.send(:ai_query, "task", "input") }.to raise_error(/ai-query failed/)
    end
  end
end
