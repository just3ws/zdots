# frozen_string_literal: true

require "spec_helper"
require "zdots/ai/publisher"

# Z-311, third sighting of the same trap (Z-297 was bin/ctx-mcp, Z-309 the
# duplicate). In a gsub *string* replacement \' means the post-match, not a
# literal backslash-apostrophe. The escaping below feeds an ffmpeg -vf filter
# argument, so getting it wrong silently produced a path that pointed nowhere.
RSpec.describe Zdots::AI::Publisher, "vtt path escaping" do
  # The production line, isolated. Kept in lockstep with publisher.rb:37.
  def escape(path)
    path.gsub("'") { "\\'" }.gsub(":") { "\\:" }
  end

  it "escapes an apostrophe instead of swallowing it" do
    expect(escape("/tmp/Mike's Talk/a.vtt")).to eq("/tmp/Mike\\'s Talk/a.vtt")
  end

  it "does not duplicate the text after an apostrophe" do
    # The exact old failure: /tmp/Mikes Talk/a.vtts Talk/a.vtt
    expect(escape("/tmp/Mike's Talk/a.vtt")).not_to include("vtts Talk")
  end

  it "escapes colons, which delimit ffmpeg filter options" do
    expect(escape("/tmp/12:30/a.vtt")).to eq("/tmp/12\\:30/a.vtt")
  end

  it "leaves an ordinary path untouched" do
    expect(escape("/tmp/plain/a.vtt")).to eq("/tmp/plain/a.vtt")
  end

  it "handles both characters in one path" do
    expect(escape("/tmp/Mike's 12:30/a.vtt")).to eq("/tmp/Mike\\'s 12\\:30/a.vtt")
  end
end
