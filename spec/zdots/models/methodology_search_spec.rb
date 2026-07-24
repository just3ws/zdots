# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "zdots"
require "zdots/models/methodology"

# Z-232: `zdots-ctx query tooling:<name>` (the AGENTS.md rule-zero contract)
# must hit — catalog entries carry their identity in the slug, not title/content.
RSpec.describe "Methodology text search", :integration do
  def record(attrs)
    Zdots::Models::Methodology.load({ content_enc: nil }.merge(attrs))
  end

  it "matches on slug" do
    rec = record(slug: "tooling:zsvc", title: "zdots command: zsvc")
    expect(Zdots::Models::Methodology.text_match?(rec, "tooling:zsvc")).to be true
  end

  it "matches on title" do
    rec = record(slug: "tooling:zsvc", title: "zdots command: zsvc")
    expect(Zdots::Models::Methodology.text_match?(rec, "command: zsvc")).to be true
  end

  it "rejects a term absent from every field" do
    rec = record(slug: "tooling:zsvc", title: "zdots command: zsvc")
    expect(Zdots::Models::Methodology.text_match?(rec, "no-such-term")).to be false
  end
end
