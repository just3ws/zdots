# frozen_string_literal: true

require "spec_helper"
require "dry/monads"
require "zdots/ai/client"
require "zdots/ai/pipeline"

RSpec.describe Zdots::AI::Pipeline do
  include Dry::Monads[:result]

  around do |example|
    saved = {
      "ZDOTS_AI_MODE"     => ENV["ZDOTS_AI_MODE"],
      "ZDOTS_AI_ENDPOINT" => ENV["ZDOTS_AI_ENDPOINT"]
    }
    Zdots::AI.reset!
    example.run
    saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
    Zdots::AI.reset!
  end

  before do
    allow(Zdots::AI).to receive(:system)
  end

  # ── Gate blocking ──────────────────────────────────────────────────────────

  describe ".call gate" do
    context "when ZDOTS_AI_MODE=none" do
      before { ENV["ZDOTS_AI_MODE"] = "none" }

      it "returns Failure[:locality, …] without calling the client" do
        expect(Zdots::AI).not_to receive(:client)
        result = described_class.call("hello")
        expect(result).to be_failure
        reason, msg = result.failure
        expect(reason).to eq(:locality)
        expect(msg).to match(/ZDOTS_AI_MODE=none/)
      end
    end

    context "when ZDOTS_AI_MODE=local with a non-local endpoint" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "local"
        ENV["ZDOTS_AI_ENDPOINT"] = "https://api.openai.com"
      end

      it "returns Failure[:locality, …] with SECURITY message" do
        result = described_class.call("hello")
        expect(result).to be_failure
        reason, msg = result.failure
        expect(reason).to eq(:locality)
        expect(msg).to match(/SECURITY/)
      end
    end
  end

  # ── Inference pipeline ─────────────────────────────────────────────────────

  describe ".call inference" do
    let(:fake_client) { instance_double(Zdots::AI::Connection) }
    let(:fake_message) { double("RubyLLM::Message", content: "PONG") }

    before do
      ENV["ZDOTS_AI_MODE"]     = "local"
      ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
      allow(Zdots::AI).to receive(:build_client).and_return(fake_client)
    end

    it "returns Success(response_text) on a clean prompt" do
      allow(fake_client).to receive(:chat).and_return(fake_message)
      result = described_class.call("ping", temperature: 0.0)
      expect(result).to be_success
      expect(result.value!).to eq("PONG")
    end

    it "passes temperature through to the client" do
      expect(fake_client).to receive(:chat).with(hash_including(temperature: 0.7)).and_return(fake_message)
      described_class.call("ping", temperature: 0.7)
    end

    it "passes system prompt when provided" do
      expect(fake_client).to receive(:chat) do |args|
        sys = args[:messages].find { |m| m[:role] == "system" }
        expect(sys[:content]).to eq("You are a test bot.")
        fake_message
      end
      described_class.call("ping", system: "You are a test bot.")
    end

    it "returns Failure[:inference_error, …] when the client raises" do
      allow(fake_client).to receive(:chat).and_raise(RuntimeError, "connection refused")
      result = described_class.call("ping")
      expect(result).to be_failure
      reason, msg = result.failure
      expect(reason).to eq(:inference_error)
      expect(msg).to include("connection refused")
    end

    it "scrubs PHI before sending to the client" do
      expect(fake_client).to receive(:chat) do |args|
        user_msg = args[:messages].find { |m| m[:role] == "user" }
        expect(user_msg[:content]).not_to match(/\d{3}-\d{2}-\d{4}/)
        expect(user_msg[:content]).to include("[REDACTED-SSN]")
        fake_message
      end
      described_class.call("patient ssn: 123-45-6789")
    end
  end

  # ── Embed pipeline ─────────────────────────────────────────────────────────

  describe ".embed" do
    let(:fake_embed_client) { instance_double(Zdots::AI::EmbedConnection) }
    let(:vector)            { Array.new(768) { rand } }

    before do
      ENV["ZDOTS_AI_MODE"]          = "local"
      ENV["ZDOTS_AI_ENDPOINT"]      = "http://127.0.0.1:11500"
      ENV["ZDOTS_AI_EMBED_ENDPOINT"] = "http://127.0.0.1:11501"
      allow(Zdots::AI).to receive(:embed_client).and_return(fake_embed_client)
    end

    it "returns Success(vector) on a valid response" do
      fake_result = Zdots::AI::EmbedConnection::EmbedResult.new(vector, vector)
      allow(fake_embed_client).to receive(:embed).and_return(fake_result)
      result = described_class.embed("hello world")
      expect(result).to be_success
      expect(result.value!).to eq(vector)
    end

    it "returns Failure[:embed_error, …] when vectors is nil" do
      fake_result = Zdots::AI::EmbedConnection::EmbedResult.new(nil, nil)
      allow(fake_embed_client).to receive(:embed).and_return(fake_result)
      result = described_class.embed("hello")
      expect(result).to be_failure
      expect(result.failure.first).to eq(:embed_error)
    end

    it "returns Failure[:embed_error, …] when vectors is empty" do
      fake_result = Zdots::AI::EmbedConnection::EmbedResult.new([], [])
      allow(fake_embed_client).to receive(:embed).and_return(fake_result)
      result = described_class.embed("hello")
      expect(result).to be_failure
      expect(result.failure.first).to eq(:embed_error)
    end

    it "returns Failure[:embed_error, …] when the client raises" do
      allow(fake_embed_client).to receive(:embed).and_raise(RuntimeError, "embed failed")
      result = described_class.embed("hello")
      expect(result).to be_failure
      reason, msg = result.failure
      expect(reason).to eq(:embed_error)
      expect(msg).to include("embed failed")
    end

    it "gate blocks embed too when ZDOTS_AI_MODE=none" do
      ENV["ZDOTS_AI_MODE"] = "none"
      result = described_class.embed("hello")
      expect(result).to be_failure
      expect(result.failure.first).to eq(:locality)
    end
  end
end
