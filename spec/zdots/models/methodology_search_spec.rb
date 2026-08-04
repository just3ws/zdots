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

  # Regression: the original substring implementation required an exact
  # contiguous phrase, so a two-word query only matched if those words were
  # adjacent in that order. "disruption assumptions" against a record whose
  # title has both words apart should still match under AND-over-words.
  it "matches multiple query words present anywhere, not as one exact phrase" do
    rec = record(slug: "d1", title: "assumptions about disruption in the industry")
    expect(Zdots::Models::Methodology.text_match?(rec, "disruption assumptions")).to be true
  end

  it "rejects when only some query words are present (AND, not OR)" do
    rec = record(slug: "d1", title: "assumptions about the industry")
    expect(Zdots::Models::Methodology.text_match?(rec, "disruption assumptions")).to be false
  end

  it "ranks a title/slug match above a content-only match" do
    title_hit = record(slug: "s1", title: "zsvc map reference", content_enc: nil)
    def title_hit.content = "unrelated body text"

    body_hit = record(slug: "s2", title: "unrelated title", content_enc: nil)
    def body_hit.content = "zsvc map appears here in the body"

    scored = [title_hit, body_hit].sort_by { |r| -Zdots::Models::Methodology.text_score(r, %w[zsvc map]) }
    expect(scored.first).to eq(title_hit)
  end
end
