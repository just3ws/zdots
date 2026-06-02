# frozen_string_literal: true

require "spec_helper"
require "zdots/ai/client"
require "ruby_llm"

RSpec.describe Zdots::AI do
  around do |example|
    saved = {
      "ZDOTS_AI_MODE" => ENV.fetch("ZDOTS_AI_MODE", nil),
      "ZDOTS_AI_ENDPOINT" => ENV.fetch("ZDOTS_AI_ENDPOINT", nil),
      "ZDOTS_AI_EMBED_ENDPOINT" => ENV.fetch("ZDOTS_AI_EMBED_ENDPOINT", nil)
    }
    described_class.reset!
    described_class.instance_variable_set(:@embed_client, nil)
    example.run
    saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
    described_class.reset!
    described_class.instance_variable_set(:@embed_client, nil)
  end

  # Silence macOS Unified Logging calls during tests
  before { allow(described_class).to receive(:system) }

  describe ".endpoint" do
    it "returns the env var when set" do
      ENV["ZDOTS_AI_ENDPOINT"] = "http://10.0.0.5:11500"
      expect(described_class.endpoint).to eq("http://10.0.0.5:11500")
    end

    it "defaults to loopback when unset" do
      ENV.delete("ZDOTS_AI_ENDPOINT")
      expect(described_class.endpoint).to start_with("http://127.")
    end
  end

  describe ".embed_endpoint" do
    it "returns the env var when set" do
      ENV["ZDOTS_AI_EMBED_ENDPOINT"] = "http://127.0.0.1:19999"
      expect(described_class.embed_endpoint).to eq("http://127.0.0.1:19999")
    end

    it "defaults to port 11501 when unset" do
      ENV.delete("ZDOTS_AI_EMBED_ENDPOINT")
      expect(described_class.embed_endpoint).to end_with(":11501")
    end
  end

  describe ".embed_client" do
    before do
      ENV["ZDOTS_AI_MODE"]     = "local"
      ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
    end

    it "returns an EmbedConnection" do
      expect(described_class.embed_client).to be_a(Zdots::AI::EmbedConnection)
    end

    it "memoizes across calls" do
      expect(described_class.embed_client).to be(described_class.embed_client)
    end

    it "raises LocalityError when ZDOTS_AI_MODE=none" do
      ENV["ZDOTS_AI_MODE"] = "none"
      expect { described_class.embed_client }.to raise_error(Zdots::AI::LocalityError)
    end
  end

  describe ".assert_local!" do
    context "when ZDOTS_AI_MODE=none" do
      before { ENV["ZDOTS_AI_MODE"] = "none" }

      it "raises LocalityError" do
        expect { described_class.assert_local! }
          .to raise_error(Zdots::AI::LocalityError, /ZDOTS_AI_MODE=none/)
      end
    end

    context "when ZDOTS_AI_MODE=cloud" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "cloud"
        ENV["ZDOTS_AI_ENDPOINT"] = "https://api.openai.com"
      end

      it "allows a non-local endpoint" do
        expect { described_class.assert_local! }.not_to raise_error
      end
    end

    context "when ZDOTS_AI_MODE=local with a loopback endpoint" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "local"
        ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
      end

      it "passes" do
        expect { described_class.assert_local! }.not_to raise_error
      end
    end

    context "when ZDOTS_AI_MODE=local with an RFC-1918 endpoint" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "local"
        ENV["ZDOTS_AI_ENDPOINT"] = "http://192.168.1.10:11500"
      end

      it "passes" do
        expect { described_class.assert_local! }.not_to raise_error
      end
    end

    context "when ZDOTS_AI_MODE=local with a non-local endpoint" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "local"
        ENV["ZDOTS_AI_ENDPOINT"] = "https://api.openai.com"
      end

      it "raises LocalityError with SECURITY prefix" do
        expect { described_class.assert_local! }
          .to raise_error(Zdots::AI::LocalityError, /SECURITY/)
      end
    end

    context "when ZDOTS_AI_MODE is unset (defaults to local)" do
      before do
        ENV.delete("ZDOTS_AI_MODE")
        ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
      end

      it "passes with loopback endpoint" do
        expect { described_class.assert_local! }.not_to raise_error
      end
    end

    context "when ZDOTS_AI_MODE=local with an unparseable URI" do
      before do
        ENV["ZDOTS_AI_MODE"] = "local"
        allow(described_class).to receive(:endpoint).and_return("http://[invalid")
      end

      it "treats the endpoint as non-local and raises LocalityError" do
        expect { described_class.assert_local! }
          .to raise_error(Zdots::AI::LocalityError, /SECURITY/)
      end
    end
  end

  describe ".client" do
    context "when ZDOTS_AI_MODE=none" do
      before { ENV["ZDOTS_AI_MODE"] = "none" }

      it "raises LocalityError without building a client" do
        expect(described_class).not_to receive(:build_client)
        expect { described_class.client }
          .to raise_error(Zdots::AI::LocalityError)
      end
    end

    context "when mode and endpoint are valid" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "local"
        ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
      end

      it "memoizes the client across calls" do
        fake_client = instance_double(Zdots::AI::Connection)
        expect(described_class).to receive(:build_client).once.and_return(fake_client)
        described_class.client
        described_class.client
      end
    end

    context "when reset! is called between calls" do
      before do
        ENV["ZDOTS_AI_MODE"]     = "local"
        ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
      end

      it "rebuilds the client after reset!" do
        fake = instance_double(Zdots::AI::Connection)
        expect(described_class).to receive(:build_client).twice.and_return(fake)
        described_class.client
        described_class.reset!
        described_class.client
      end
    end
  end

  describe "private .build_client" do
    let(:config_dbl) do
      double("RubyLLMConfig").tap do |c|
        allow(c).to receive(:openai_api_key=)
        allow(c).to receive(:openai_api_base=)
        allow(c).to receive(:openai_use_system_role=)
        allow(c).to receive(:default_model=)
        allow(c).to receive(:request_timeout=)
      end
    end

    before do
      ENV["ZDOTS_AI_MODE"]     = "local"
      ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
      allow(RubyLLM).to receive(:configure).and_yield(config_dbl)
    end

    it "returns a Connection" do
      expect(described_class.send(:build_client)).to be_a(Zdots::AI::Connection)
    end

    it "configures the openai_api_base from the current endpoint" do
      expect(config_dbl).to receive(:openai_api_base=).with("http://127.0.0.1:11500/v1")
      described_class.send(:build_client)
    end
  end

  describe "private .reset_clients!" do
    before do
      ENV["ZDOTS_AI_MODE"]     = "local"
      ENV["ZDOTS_AI_ENDPOINT"] = "http://127.0.0.1:11500"
    end

    it "clears embed_client so the next call allocates a new instance" do
      first = described_class.embed_client
      described_class.send(:reset_clients!)
      second = described_class.embed_client
      expect(second).not_to be(first)
    end

    it "clears the chat client so the next call goes through build_client again" do
      fake = instance_double(Zdots::AI::Connection)
      allow(described_class).to receive(:build_client).and_return(fake)
      described_class.client
      described_class.send(:reset_clients!)
      expect(described_class).to receive(:build_client).once
      described_class.client
    end
  end

  describe "private .audit_log" do
    def expect_log_call(type:, event:, detail: "")
      expect(described_class).to receive(:system).with(
        "/usr/bin/log", "emit",
        "--subsystem", "com.zdots",
        "--category",  "phi-boundary",
        "--type",      type,
        "--public",
        "event=#{event} #{detail}",
        exception: false
      )
    end

    it "emits type=default for unclassified event names" do
      expect_log_call(type: "default", event: "ai_started", detail: "service=llama")
      described_class.send(:audit_log, "ai_started", "service=llama")
    end

    it "emits type=fault for _fail/_triggered/_violation events" do
      expect_log_call(type: "fault", event: "endpoint_assertion_fail")
      described_class.send(:audit_log, "endpoint_assertion_fail")
    end

    it "emits type=info for _pass/_redacted events" do
      expect_log_call(type: "info", event: "endpoint_assertion_pass")
      described_class.send(:audit_log, "endpoint_assertion_pass")
    end
  end
end

RSpec.describe Zdots::AI::EmbedConnection do
  subject(:conn) { described_class.new }

  let(:http)    { instance_double(Net::HTTP) }
  let(:vector)  { [0.1, 0.2, 0.3] }
  let(:ok_body) { JSON.generate({ data: [{ embedding: vector }] }) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
  end

  describe "#embed" do
    context "when the server returns 200 with a valid embedding" do
      let(:response) { instance_double(Net::HTTPResponse, code: "200", body: ok_body) }

      it "returns an EmbedResult with the vector" do
        result = conn.embed(model: "nomic-embed-text", input: "hello")
        expect(result.embedding).to eq(vector)
        expect(result.vectors).to eq(vector)
      end

      it "POSTs to /v1/embeddings" do
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq("/v1/embeddings")
          response
        end
        conn.embed(model: "nomic-embed-text", input: "hello")
      end

      it "encodes the input in the JSON body" do
        allow(http).to receive(:request) do |req|
          expect(JSON.parse(req.body)["input"]).to eq("hello")
          response
        end
        conn.embed(model: "nomic-embed-text", input: "hello")
      end
    end

    context "when the server returns a non-200 status" do
      let(:response) { instance_double(Net::HTTPResponse, code: "503", body: "Service Unavailable") }

      it "raises with the status code" do
        expect { conn.embed(model: "m", input: "x") }
          .to raise_error(RuntimeError, /503/)
      end
    end

    context "when the response contains an empty embedding array" do
      let(:response) do
        instance_double(Net::HTTPResponse,
                        code: "200",
                        body: JSON.generate({ data: [{ embedding: [] }] }))
      end

      it "raises Empty embedding" do
        expect { conn.embed(model: "m", input: "x") }
          .to raise_error(RuntimeError, /Empty embedding/)
      end
    end

    context "when the embedding key is absent from the response" do
      let(:response) do
        instance_double(Net::HTTPResponse,
                        code: "200",
                        body: JSON.generate({ data: [{}] }))
      end

      it "raises Empty embedding" do
        expect { conn.embed(model: "m", input: "x") }
          .to raise_error(RuntimeError, /Empty embedding/)
      end
    end
  end
end

RSpec.describe Zdots::AI::Connection do
  subject(:conn) { described_class.new }

  let(:response) { instance_double(RubyLLM::Message, content: "response text") }
  let(:chat_obj) do
    instance_double(RubyLLM::Chat).tap do |c|
      allow(c).to receive(:with_temperature).and_return(c)
      allow(c).to receive(:with_instructions).and_return(c)
      allow(c).to receive(:ask).and_return(response)
    end
  end

  before { allow(RubyLLM).to receive(:chat).and_return(chat_obj) }

  describe "#chat" do
    let(:messages) do
      [
        { role: "system", content: "You are helpful." },
        { role: "user",   content: "Hello" }
      ]
    end

    it "sends the user message and returns the AI response" do
      result = conn.chat(model: "local", messages: messages, temperature: 0.7)
      expect(chat_obj).to have_received(:ask).with("Hello")
      expect(result.content).to eq("response text")
    end

    it "applies system instructions when a system message is present" do
      conn.chat(model: "local", messages: messages, temperature: nil)
      expect(chat_obj).to have_received(:with_instructions).with("You are helpful.")
    end

    it "skips with_instructions when no system message is present" do
      conn.chat(model: "local", messages: [{ role: "user", content: "Hi" }], temperature: nil)
      expect(chat_obj).not_to have_received(:with_instructions)
    end

    it "applies temperature when non-nil" do
      conn.chat(model: "local", messages: messages, temperature: 0.5)
      expect(chat_obj).to have_received(:with_temperature).with(0.5)
    end

    it "skips with_temperature when temperature is nil" do
      conn.chat(model: "local", messages: messages, temperature: nil)
      expect(chat_obj).not_to have_received(:with_temperature)
    end
  end

  describe "#embed" do
    it "delegates to RubyLLM.embed with provider and model options" do
      embed_result = instance_double(RubyLLM::Embedding)
      allow(RubyLLM).to receive(:embed).and_return(embed_result)

      result = conn.embed(model: "nomic-embed-text", input: "hello world")

      expect(RubyLLM).to have_received(:embed).with(
        "hello world",
        hash_including(provider: "openai", model: "nomic-embed-text")
      )
      expect(result).to be(embed_result)
    end
  end
end
