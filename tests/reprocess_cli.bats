#!/usr/bin/env bats
# tests/reprocess_cli.bats — Z-188 P1 wiring/guard contract for `zdots-ctx reprocess`.
#
# reprocess is implemented in sbin/zdots-brain (cmd_reprocess) and fronted by
# bin/zdots-ctx (dispatch → delegation). This asserts the command is wired
# end-to-end and that its arg guards fire BEFORE any job is enqueued, so a bad or
# empty invocation can never mutate the queue. It deliberately does NOT exercise
# the re-enqueue / raw-stage-clear path: a real reprocess enqueues a transcription
# job, so live end-to-end is an operator step (see Z-188 notes), not a unit test.

setup() {
  load "setup.bash"
  setup_environment
  ROOT="$REPO_ROOT"
}

@test "zdots-ctx reprocess with no source prints usage and exits non-zero" {
  run "$ROOT/bin/zdots-ctx" reprocess
  assert_failure
  assert_output --partial "usage:"
  assert_output --partial "reprocess"
}

@test "zdots-ctx reprocess with an unmatchable token refuses (never enqueues)" {
  # An absurd token can't match any source_uri/title/id → resolve_media_source
  # must bail with 'no media source matching' and exit non-zero, proving the
  # resolution guard runs before the enqueue and won't queue work on bad input.
  run "$ROOT/bin/zdots-ctx" reprocess "zzzz-no-such-media-source-zzzz"
  assert_failure
  assert_output --partial "no media source matching"
}
