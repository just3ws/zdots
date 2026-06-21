#!/usr/bin/env bats
# tests/ingest_media_cloud_distill.bats — the safety gate for the scoped cloud
# distill (ADR-0003). Asserts that the public-content gate refuses the cloud
# path for non-public sources even with the flag on and a key present, and
# permits it only for public sources with a key. Pure gate logic — never makes
# a network call.

setup() {
  load "setup.bash"
  setup_environment
  ROOT="$REPO_ROOT"
}

# Evaluate cloud_distill_eligible? for a given source_type + key, with the flag ON.
# Echoes "eligible" or "blocked".
_gate() {
  local src_type="$1" key="$2"
  ZDOTS_DISTILL_CLOUD=1 ruby -e '
    require "'"$ROOT"'/lib/zdots"
    require "'"$ROOT"'/lib/zdots/jobs/ingest_media"
    o = Zdots::Jobs::IngestMedia.allocate
    st = ARGV[0].empty? ? nil : Struct.new(:source_type).new(ARGV[0])
    o.instance_variable_set(:@src, st)
    o.instance_variable_set(:@anthropic_key, ARGV[1])
    puts o.send(:cloud_distill_eligible?) ? "eligible" : "blocked"
  ' "$src_type" "$key" 2>/dev/null
}

@test "cloud distill: local-file source is BLOCKED even with flag on + key" {
  [ "$(_gate file sk-key)" = "blocked" ]
}

@test "cloud distill: empty/unknown source is BLOCKED" {
  [ "$(_gate '' sk-key)" = "blocked" ]
  [ "$(_gate url sk-key)" = "blocked" ]
}

@test "cloud distill: youtube/vimeo + key are ELIGIBLE" {
  [ "$(_gate youtube sk-key)" = "eligible" ]
  [ "$(_gate vimeo sk-key)" = "eligible" ]
}

@test "cloud distill: public source with NO key is BLOCKED" {
  [ "$(_gate youtube '')" = "blocked" ]
}

@test "cloud distill: flag OFF blocks even public source + key" {
  run bash -c "ZDOTS_DISTILL_CLOUD=0 ruby -e '
    require \"$ROOT/lib/zdots\"
    require \"$ROOT/lib/zdots/jobs/ingest_media\"
    o = Zdots::Jobs::IngestMedia.allocate
    o.instance_variable_set(:@src, Struct.new(:source_type).new(\"youtube\"))
    o.instance_variable_set(:@anthropic_key, \"sk-key\")
    puts o.send(:cloud_distill_eligible?) ? \"eligible\" : \"blocked\"
  ' 2>/dev/null"
  [ "$output" = "blocked" ]
}
