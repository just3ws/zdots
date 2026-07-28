# frozen_string_literal: true

require "spec_helper"
require "dry/monads"
require "zdots/ai/client" # defines Zdots::AI.client so the negative expectation can verify it
require "zdots/jobs/docs_sync"

RSpec.describe Zdots::Jobs::DocsSync do
  include Dry::Monads[:result]

  subject(:job) { described_class.new(double("job")) }

  before do
    # Avoid touching the prompt template on disk — the prompt content is not
    # what these tests assert.
    allow(job).to receive(:load_prompt).and_return("PROMPT")
  end

  describe "#sync_document" do
    it "routes inference through Pipeline (not the raw client) and returns new content" do
      expect(Zdots::AI::Pipeline).to receive(:call)
        .with("PROMPT", temperature: 0.1)
        .and_return(Success("# Updated README"))

      result = job.send(:sync_document, "README.md", "old content", "a summary", "a result")
      expect(result).to eq("# Updated README")
    end

    it "returns nil when the model reports no changes" do
      allow(Zdots::AI::Pipeline).to receive(:call).and_return(Success("NO_CHANGES_REQUIRED\n"))
      expect(job.send(:sync_document, "README.md", "old", "s", "r")).to be_nil
    end

    it "skips (returns nil) on a PHI-suppressed residue — deterministic, retrying can never succeed" do
      allow(Zdots::AI::Pipeline).to receive(:call).and_return(Failure([:phi_suppressed, "refused"]))
      expect(job.send(:sync_document, "README.md", "old", "s", "r")).to be_nil
    end

    it "raises on a locality gate failure" do
      allow(Zdots::AI::Pipeline).to receive(:call).and_return(Failure([:locality, "not local"]))
      expect { job.send(:sync_document, "README.md", "old", "s", "r") }
        .to raise_error(/AI pipeline failed \(locality\)/)
    end

    it "never reaches the raw AI client" do
      allow(Zdots::AI::Pipeline).to receive(:call).and_return(Success("x"))
      expect(Zdots::AI).not_to receive(:client)
      job.send(:sync_document, "README.md", "old", "s", "r")
    end
  end

  describe "#fictional_paths" do
    before { stub_const("Zdots::ZDOTDIR", File.expand_path("../../..", __dir__)) }

    it "flags added repo paths that do not exist (the Z-228 hallucination gate)" do
      old_doc = "See docs/architecture.md."
      new_doc = "See docs/architecture.md and tests/ssh.bats plus bin/zdots-ctl."
      expect(job.send(:fictional_paths, old_doc, new_doc)).to eq(["tests/ssh.bats"])
    end

    it "does not flag paths already present in the old content" do
      doc = "Historic mention of tests/removed_thing.bats stays untouched."
      expect(job.send(:fictional_paths, doc, doc)).to be_empty
    end

    it "does not mistake absolute system paths for repo paths" do
      expect(job.send(:fictional_paths, "", "Use /usr/bin/env and /etc/hosts.")).to be_empty
    end
  end

  describe "#utf8" do
    it "replaces invalid byte sequences instead of raising (Z-225)" do
      dirty = "caf\xE9".dup.force_encoding("UTF-8")
      expect { job.send(:utf8, dirty).strip }.not_to raise_error
      expect(job.send(:utf8, dirty)).to be_valid_encoding
    end
  end
end
