# frozen_string_literal: true

require "spec_helper"
require "zdots/ai/client"

RSpec.describe Zdots::AI do
  around do |example|
    saved = {
      "ZDOTS_AI_MODE" => ENV.fetch("ZDOTS_AI_MODE", nil),
      "ZDOTS_AI_ENDPOINT" => ENV.fetch("ZDOTS_AI_ENDPOINT", nil)
    }
    described_class.reset!
    example.run
    saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
    described_class.reset!
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
end
