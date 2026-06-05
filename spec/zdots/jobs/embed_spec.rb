# frozen_string_literal: true

require "spec_helper"
require "dry/monads"
require "zdots/jobs/embed"

RSpec.describe Zdots::Jobs::Embed do
  include Dry::Monads[:result]

  subject(:job) { described_class.new(nil) }
  let(:max) { described_class::MAX_CHARS }

  describe "#chunk" do
    it "returns the whole text as one chunk when within the budget" do
      text = "short content"
      expect(job.send(:chunk, text)).to eq([text])
    end

    it "splits long text into chunks each within the budget" do
      text = (["lorem ipsum dolor sit amet"] * 400).join(" ") # well over MAX_CHARS
      chunks = job.send(:chunk, text)
      expect(chunks.size).to be > 1
      expect(chunks).to all(satisfy { |c| c.length <= max })
    end

    it "preserves all words across chunk boundaries" do
      words = (1..600).map { |n| "word#{n}" }
      chunks = job.send(:chunk, words.join(" "))
      expect(chunks.join(" ").split).to eq(words)
    end

    it "hard-splits a single token longer than the budget" do
      giant = "x" * (max * 2 + 50)
      chunks = job.send(:chunk, giant)
      expect(chunks.size).to eq(3)
      expect(chunks).to all(satisfy { |c| c.length <= max })
      expect(chunks.join).to eq(giant)
    end
  end

  describe "#mean_pool" do
    it "passes a single vector through unchanged" do
      v = [0.1, 0.2, 0.3]
      expect(job.send(:mean_pool, [v])).to eq(v)
    end

    it "averages and L2-normalizes multiple vectors" do
      pooled = job.send(:mean_pool, [[1.0, 0.0], [0.0, 1.0]])
      # mean = [0.5, 0.5]; normalized → [0.7071…, 0.7071…]
      expect(pooled[0]).to be_within(1e-9).of(Math.sqrt(0.5))
      expect(pooled[1]).to be_within(1e-9).of(Math.sqrt(0.5))
      expect(Math.sqrt(pooled.sum { |x| x * x })).to be_within(1e-9).of(1.0)
    end
  end

  describe "#embed_document" do
    it "embeds short text with a single pipeline call" do
      allow(Zdots::AI::Pipeline).to receive(:embed).and_return(Success([1.0, 0.0, 0.0]))
      result = job.send(:embed_document, "short")
      expect(Zdots::AI::Pipeline).to have_received(:embed).once
      expect(result).to eq([1.0, 0.0, 0.0])
    end

    it "embeds each chunk and mean-pools when text is long" do
      allow(Zdots::AI::Pipeline).to receive(:embed).and_return(Success([1.0, 0.0]), Success([0.0, 1.0]))
      long = (["alpha beta gamma delta"] * 200).join(" ")
      expect(job.send(:chunk, long).size).to be >= 2
      result = job.send(:embed_document, long)
      expect(Zdots::AI::Pipeline).to have_received(:embed).at_least(:twice)
      expect(result.size).to eq(2)
    end

    it "raises when the pipeline fails (e.g. PHI-suppressed chunk)" do
      failed = double("result", success?: false, failure: [:phi_suppressed, "nope"])
      allow(Zdots::AI::Pipeline).to receive(:embed).and_return(failed)
      expect { job.send(:embed_document, "secret") }.to raise_error(/Embed pipeline failed/)
    end
  end
end
