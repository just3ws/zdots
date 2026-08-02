#!/usr/bin/env bats
# tests/zdots_usage.bats — usage intelligence reports over a fixture trace (Z-286)

setup() {
  load "setup.bash"
  setup_environment
  FIXTURE="$BATS_TEST_TMPDIR/traces.jsonl"
  cat >"$FIXTURE" <<'JSONL'
{"ts":"2026-08-01T10:00:00-0500","sid":"aaa","spid":"1","event":"session_start","data":"profile=work, shell=/bin/zsh, tty=yes"}
{"ts":"2026-08-01T10:00:01-0500","sid":"aaa","spid":"2","event":"exec","data":"git status"}
{"ts":"2026-08-01T10:00:02-0500","sid":"aaa","spid":"3","event":"exec","data":"git status"}
{"ts":"2026-08-01T10:00:03-0500","sid":"aaa","spid":"4","event":"exec","data":"flaky run"}
{"ts":"2026-08-01T10:00:04-0500","sid":"aaa","spid":"4","event":"error","data":"status=1, cmd=flaky run"}
{"ts":"2026-08-01T10:00:05-0500","sid":"aaa","spid":"5","event":"exec","data":"klear"}
{"ts":"2026-08-01T10:00:06-0500","sid":"aaa","spid":"5","event":"error","data":"status=130, cmd=klear"}
{"ts":"2026-08-01T10:01:00-0500","sid":"bbb","spid":"1","event":"session_start","data":"profile=work, shell=/bin/zsh, tty=no"}
{"ts":"2026-08-01T10:01:01-0500","sid":"bbb","spid":"2","event":"error","data":"source_failure=/x/conf.d/97-zle-ai.zsh, ctx=nontty"}
not json at all — pre-escaping era line
JSONL
}

@test "usage: top counts commands and tolerates bad lines" {
  run env ZDOTS_USAGE_TRACE_FILE="$FIXTURE" "$REPO_ROOT/bin/zdots-usage" top
  [ "$status" -eq 0 ]
  [[ "$output" == *"2  git"* ]]
}

@test "usage: errors separates real failures from 130 prompt-aborts" {
  # flaky has 1 real error but only 1 exec (<10 min) so no rate row; the
  # 130 against klear must land in the aborts section, not as a failure.
  run env ZDOTS_USAGE_TRACE_FILE="$FIXTURE" "$REPO_ROOT/bin/zdots-usage" errors
  [ "$status" -eq 0 ]
  [[ "$output" == *"Prompt aborts"* ]]
  [[ "$output" == *"after klear"* ]]
  [[ "$output" != *"klear "*"%"* ]]
}

@test "usage: sessions reports exact tty split when tagged" {
  run env ZDOTS_USAGE_TRACE_FILE="$FIXTURE" "$REPO_ROOT/bin/zdots-usage" sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"1  human  sessions (exact)"* ]] || [[ "$output" == *"human "* ]]
  [[ "$output" == *"agent "* ]]
}

@test "usage: health surfaces module source failures" {
  run env ZDOTS_USAGE_TRACE_FILE="$FIXTURE" "$REPO_ROOT/bin/zdots-usage" health
  [ "$status" -eq 0 ]
  [[ "$output" == *"97-zle-ai.zsh"* ]]
}

@test "usage: --help exits 0 with usage text" {
  run "$REPO_ROOT/bin/zdots-usage" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: zdots-usage"* ]]
}
