#!/usr/bin/env bats
# tests/ingest_media_cloud_distill.bats — the safety gate for the scoped cloud
# distill (ADR-0003). Asserts that the public-content gate refuses the cloud
# path for non-public sources even with the flag on and the claude CLI present,
# and permits it only for public sources when claude is available. Pure gate
# logic — never invokes the claude CLI or makes a network call.

setup() {
  load "setup.bash"
  setup_environment
  ROOT="$REPO_ROOT"
}

# Evaluate cloud_distill_eligible? for a source_type + claude-bin path, flag ON.
# Echoes "eligible" or "blocked". An empty claude path = claude unavailable.
_gate() {
  local src_type="$1" claude_bin="$2"
  ZDOTS_DISTILL_CLOUD=1 ruby -e '
    require "'"$ROOT"'/lib/zdots"
    require "'"$ROOT"'/lib/zdots/jobs/ingest_media"
    o = Zdots::Jobs::IngestMedia.allocate
    st = ARGV[0].empty? ? nil : Struct.new(:source_type).new(ARGV[0])
    o.instance_variable_set(:@src, st)
    o.instance_variable_set(:@claude_bin, ARGV[1])   # bypass `command -v claude`
    puts o.send(:cloud_distill_eligible?) ? "eligible" : "blocked"
  ' "$src_type" "$claude_bin" 2>/dev/null
}

@test "cloud distill: local-file source is BLOCKED even with flag on + claude present" {
  [ "$(_gate file /usr/bin/claude)" = "blocked" ]
}

@test "cloud distill: empty/unknown source is BLOCKED" {
  [ "$(_gate '' /usr/bin/claude)" = "blocked" ]
  [ "$(_gate url /usr/bin/claude)" = "blocked" ]
}

@test "cloud distill: youtube/vimeo with claude present are ELIGIBLE" {
  [ "$(_gate youtube /usr/bin/claude)" = "eligible" ]
  [ "$(_gate vimeo /usr/bin/claude)" = "eligible" ]
}

@test "cloud distill: public source but claude NOT available is BLOCKED" {
  [ "$(_gate youtube '')" = "blocked" ]
}

@test "cloud distill: flag OFF blocks even public source + claude present" {
  run bash -c "ZDOTS_DISTILL_CLOUD=0 ruby -e '
    require \"$ROOT/lib/zdots\"
    require \"$ROOT/lib/zdots/jobs/ingest_media\"
    o = Zdots::Jobs::IngestMedia.allocate
    o.instance_variable_set(:@src, Struct.new(:source_type).new(\"youtube\"))
    o.instance_variable_set(:@claude_bin, \"/usr/bin/claude\")
    puts o.send(:cloud_distill_eligible?) ? \"eligible\" : \"blocked\"
  ' 2>/dev/null"
  [ "$output" = "blocked" ]
}
