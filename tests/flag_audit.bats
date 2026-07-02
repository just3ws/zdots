#!/usr/bin/env bats
# tests/flag_audit.bats — destructive-subcommand --help invariant (regression guard)
#
# WHAT: Every destructive "<command> <subcommand>" pair must honor -h/--help by
# printing usage and exiting 0 *before* any side effect. This is the recurring
# codification of the one-off flag-audit that produced commit
# "fix(cli): subcommands honor -h/--help before destructive side effects (Z-182)".
#
# WHY: The hand-audit fixed 10 footguns at once. A hand-audit is a snapshot; this
# file is the every-commit check that keeps the footgun class from silently
# returning — the self-improvement loop turning a one-off audit into a standing
# invariant. Sibling: tests/docs_contract.bats (same setup() helper, same
# REPO_ROOT/BIN usage, same _known_gap allowlist idiom).
#
# CONTRACT: <cmd> <subcmd> --help  ->  status 0  AND  usage/commands in output.
# We never run these subcommands beyond --help; that is the whole point — --help
# must be the inert path through an otherwise destructive verb.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
}

# Reuse the docs-contract known-gaps allowlist for any sanctioned exception.
# A gap here must correspond to a backlog issue (enforced by docs_contract.bats).
# Format key for a pair is "<cmd> <subcmd>" (whole-line match in the gaps file).
_known_gap() {
  local name="$1"
  grep -q "^${name}:" "$REPO_ROOT/docs/generated/docs-contract-known-gaps.txt"
}

# _assert_help_inert <cmd> <subcmd>
# Runs `<cmd> <subcmd> --help` and asserts the inert-usage contract, unless the
# pair (or the bare command) is a sanctioned known gap.
_assert_help_inert() {
  local cmd="$1" sub="$2"
  if _known_gap "$cmd $sub" || _known_gap "$cmd"; then
    return 0
  fi
  run "$BIN/$cmd" "$sub" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Uu]sage|[Cc]ommands?: ]]
}

@test "flag-audit: zdots-ctx destructive subcommands honor --help" {
  _assert_help_inert zdots-ctx migrate
  _assert_help_inert zdots-ctx init-db
}

@test "flag-audit: zdots-ctl destructive subcommands honor --help" {
  _assert_help_inert zdots-ctl down
  _assert_help_inert zdots-ctl reset
  _assert_help_inert zdots-ctl up
  _assert_help_inert zdots-ctl install
}

@test "flag-audit: llama-ctl destructive subcommands honor --help" {
  _assert_help_inert llama-ctl model-prune
  _assert_help_inert llama-ctl install
}

@test "flag-audit: local-ci destructive subcommands honor --help" {
  _assert_help_inert local-ci rebuild
  _assert_help_inert local-ci prune
}

@test "flag-audit: openobserve-ctl destructive subcommands honor --help" {
  _assert_help_inert openobserve-ctl reinit
  _assert_help_inert openobserve-ctl install
  _assert_help_inert openobserve-ctl serve
}

@test "flag-audit: otel-collector destructive subcommands honor --help" {
  _assert_help_inert otel-collector stop
  _assert_help_inert otel-collector restart
}

@test "flag-audit: whisper-ctl destructive subcommands honor --help" {
  _assert_help_inert whisper-ctl install
  _assert_help_inert whisper-ctl model-download
}

@test "flag-audit: zdots-keychain destructive subcommands honor --help" {
  _assert_help_inert zdots-keychain delete
}

@test "flag-audit: ztask destructive subcommands honor --help" {
  _assert_help_inert ztask done
  _assert_help_inert ztask stop
}

@test "flag-audit: zdots-worker destructive subcommands honor --help" {
  _assert_help_inert zdots-worker install
}
