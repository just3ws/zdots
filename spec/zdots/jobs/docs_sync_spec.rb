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

    it "raises on a pipeline failure (e.g. a PHI-suppressed residue)" do
      allow(Zdots::AI::Pipeline).to receive(:call).and_return(Failure([:phi_suppressed, "refused"]))
      expect { job.send(:sync_document, "README.md", "old", "s", "r") }
        .to raise_error(/AI pipeline failed \(phi_suppressed\)/)
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
end
