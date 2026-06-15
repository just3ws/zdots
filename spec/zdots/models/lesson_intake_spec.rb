# frozen_string_literal: true

require "spec_helper"
require "sequel"

# Stub Sequel.pg_array so the unit spec runs without a live DB connection.
module Sequel
  def self.pg_array(arr)
    arr
  end
end

require "zdots/models/lesson_intake"

# Minimal Lesson stub — no DB, no encryption.
module Zdots
  module Models
    class Lesson
      def self.create(**attrs)
        new(**attrs)
      end

      def self.where(**_attrs)
        NullRelation.new
      end

      attr_reader :attrs

      def initialize(**attrs)
        @attrs = attrs
      end
    end

    class NullRelation
      def first = nil
    end
  end
end

RSpec.describe Zdots::Models::LessonIntake do
  subject(:intake) { described_class }

  describe ".create" do
    shared_examples "a Lesson with source_type" do |expected_type|
      it "passes source_type #{expected_type.inspect} to Lesson.create" do
        expect(Zdots::Models::Lesson).to receive(:create).with(
          hash_including(source_type: expected_type)
        ).and_call_original

        subject
      end
    end

    context "source_type: 'user'" do
      subject { intake.create(content: "tip", source_type: "user") }

      include_examples "a Lesson with source_type", "user"

      it "sets source_trace_id to nil" do
        expect(Zdots::Models::Lesson).to receive(:create).with(
          hash_including(source_trace_id: nil)
        ).and_call_original
        subject
      end
    end

    context "source_type: 'capture'" do
      subject { intake.create(content: "tip", source_type: "capture", trace_id: "abc-123") }

      include_examples "a Lesson with source_type", "capture"

      it "forwards trace_id verbatim as source_trace_id" do
        expect(Zdots::Models::Lesson).to receive(:create).with(
          hash_including(source_trace_id: "abc-123")
        ).and_call_original
        subject
      end
    end

    context "source_type: 'ingest'" do
      subject { intake.create(content: "tip", source_type: "ingest", slug: "my-lesson") }

      include_examples "a Lesson with source_type", "ingest"

      it "derives source_trace_id as 'ingest:<slug>'" do
        expect(Zdots::Models::Lesson).to receive(:create).with(
          hash_including(source_trace_id: "ingest:my-lesson")
        ).and_call_original
        subject
      end

      it "raises when slug is missing" do
        expect { intake.create(content: "tip", source_type: "ingest") }
          .to raise_error(ArgumentError, /slug required/)
      end
    end

    context "source_type: 'distill'" do
      subject { intake.create(content: "tip", source_type: "distill", trace_id: "job-xyz") }

      include_examples "a Lesson with source_type", "distill"

      it "forwards trace_id verbatim as source_trace_id" do
        expect(Zdots::Models::Lesson).to receive(:create).with(
          hash_including(source_trace_id: "job-xyz")
        ).and_call_original
        subject
      end
    end

    it "raises on an unknown source_type" do
      expect { intake.create(content: "tip", source_type: "mystery") }
        .to raise_error(ArgumentError, /unknown source_type/)
    end

    it "returns the created Lesson" do
      result = intake.create(content: "hello", source_type: "user")
      expect(result).to be_a(Zdots::Models::Lesson)
    end
  end

  describe ".find_ingested" do
    it "queries by source_trace_id 'ingest:<slug>'" do
      expect(Zdots::Models::Lesson).to receive(:where).with(source_trace_id: "ingest:some-slug")
        .and_return(Zdots::Models::NullRelation.new)
      intake.find_ingested("some-slug")
    end

    it "returns nil when no matching Lesson exists" do
      expect(intake.find_ingested("nonexistent")).to be_nil
    end
  end
end
