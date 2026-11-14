# frozen_string_literal: true

require "spec_helper"
require "zdots/contracts/ingest_media_payload"
require "zdots/pipeline_events"
require "zdots/ai/phi_scrubber"

RSpec.describe "Zdots RBS Runtime Contracts" do
  describe Zdots::Contracts::IngestMediaPayload do
    let(:valid_raw) do
      {
        "source_type" => "youtube",
        "source_uri" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "source_id" => "dQw4w9WgXcQ",
        "title" => "Architectural Seams",
        "duration_sec" => 942,
        "profile" => "standard",
        "force" => true,
        "primer_text" => "  Software Craftsmanship McHenry County  ",
        "tags" => ["scmc", " ruby ", "scmc", ""],
        "num_speakers" => 2,
        "transcript_text" => "Hello world",
        "transcript_vtt" => "WEBVTT\n\n00:00.000 --> 00:01.000\nHello world\n",
        "traceparent" => "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
        "panoramic_run_id" => "run-123"
      }
    end

    it "normalizes and freezes a valid cross-repo ingest payload" do
      contract = described_class.from_hash(valid_raw, env: {})
      expect(contract.source_uri).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      expect(contract.profile).to eq("standard")
      expect(contract.force).to be(true)
      expect(contract.primer_text).to eq("Software Craftsmanship McHenry County")
      expect(contract.tags).to eq(%w[scmc ruby])
      expect(contract.panoramic_meta["trace_id"]).to eq("4bf92f3577b34da6a3ce929d0e0e4736")
      expect(contract.panoramic_meta["parent_span_id"]).to eq("00f067aa0ba902b7")
      expect(contract.panoramic_meta["panoramic_run_id"]).to eq("run-123")

      job_hash = contract.job_payload(media_source_id: 42)
      expect(job_hash).to include(
        "media_source_id" => 42,
        "profile" => "standard",
        "num_speakers" => 2,
        "panoramic_run_id" => "run-123"
      )
    end

    it "rejects missing source_uri, unknown whisper profiles, and invalid speaker counts" do
      expect {
        described_class.from_hash({ "source_uri" => "  " }, env: {})
      }.to raise_error(Zdots::Contracts::Error, /source_uri is required/)

      expect {
        described_class.from_hash(valid_raw.merge("profile" => "turbo-ultra"), env: {})
      }.to raise_error(Zdots::Contracts::Error, /unsupported whisper profile/)

      expect {
        described_class.from_hash(valid_raw.merge("num_speakers" => 0), env: {})
      }.to raise_error(Zdots::Contracts::Error, /num_speakers must be a positive Integer/)
    end
  end

  describe Zdots::PipelineEvents::Record do
    let(:fake_job) do
      Struct.new(:id, :type, :attempts, :payload).new(
        "550e8400-e29b-41d4-a716-446655440000",
        "ingest_media",
        1,
        { "media_source_id" => 99 }
      )
    end

    it "builds a schema-compliant pipeline event record" do
      rec = Zdots::PipelineEvents.build_record("started", fake_job)
      expect(rec.event).to eq("started")
      expect(rec.job_id).to eq("550e8400-e29b-41d4-a716-446655440000")
      expect(rec.attempt).to eq(1)
      expect(rec.media_source_id).to eq(99)
      expect(rec.to_payload).to include(
        "job_id" => "550e8400-e29b-41d4-a716-446655440000",
        "job_type" => "ingest_media",
        "event" => "started",
        "attempt" => 1,
        "media_source_id" => 99
      )
    end

    it "rejects unknown pipeline event names" do
      expect {
        described_class.new(
          ts: "2026-11-14T00:00:00.000Z",
          job_id: "job-1",
          job_type: "ingest_media",
          event: "paused"
        )
      }.to raise_error(ArgumentError, /invalid pipeline event/)
    end
  end
end
