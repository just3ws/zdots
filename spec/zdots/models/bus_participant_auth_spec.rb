# frozen_string_literal: true

require "spec_helper"
require "zdots"
require "zdots/bus"

# Z-310. Before this, Bus.post resolved a participant with find_or_create, so
# any name it was handed became a real identity. On 2026-08-22 one actor used
# that to stage a two-party "handshake" between two invented peers, each
# acknowledging work the other had never done.
#
# The whole suite runs inside a transaction that always rolls back, so it
# leaves no participants, channels, or messages behind.
RSpec.describe Zdots::Models::BusParticipant, :integration do
  let(:channel) { "spec-bus-auth" }
  let(:name)    { "spec-participant" }

  around do |example|
    Zdots.db.transaction(rollback: :always) { example.run }
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  describe ".authenticate!" do
    it "refuses a name that was never registered" do
      expect { described_class.authenticate!("never-registered", "any-token") }
        .to raise_error(described_class::AuthError, /unknown participant/)
    end

    it "refuses a participant that predates tokens" do
      described_class.create(name: name, kind: "agent")
      expect { described_class.authenticate!(name, "any-token") }
        .to raise_error(described_class::AuthError, /predates authentication/)
    end

    it "refuses the right name with the wrong token" do
      described_class.issue_token!(name)
      expect { described_class.authenticate!(name, "wrong-token") }
        .to raise_error(described_class::AuthError, /bad token/)
    end

    it "accepts the token it issued" do
      _p, token = described_class.issue_token!(name)
      expect(described_class.authenticate!(name, token).name).to eq(name)
    end

    it "invalidates the old token when a name is re-registered" do
      _p, first = described_class.issue_token!(name)
      described_class.issue_token!(name)
      expect { described_class.authenticate!(name, first) }
        .to raise_error(described_class::AuthError, /bad token/)
    end
  end

  describe "Bus.post" do
    it "will not mint an identity for an unregistered name" do
      Zdots::Bus.create_channel(channel)
      expect { Zdots::Bus.post(channel, "impostor", "I am whoever I say I am") }
        .to raise_error(described_class::AuthError)
      expect(described_class.find(name: "impostor")).to be_nil
    end

    it "accepts a post whose token checks out" do
      Zdots::Bus.create_channel(channel)
      _p, token = described_class.issue_token!(name)
      msg = Zdots::Bus.post(channel, name, "registered, therefore posting", token: token)
      expect(msg.body).to eq("registered, therefore posting")
    end
  end
end
