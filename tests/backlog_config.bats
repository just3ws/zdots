#!/usr/bin/env bats
# tests/backlog_config.bats — Backlog.md repo integration contract.

setup() {
  load "setup.bash"
  setup_environment
}

_config_value() {
  backlog config get "$1"
}

@test "backlog config avoids remote and browser side effects" {
  run _config_value remoteOperations
  [ "$status" -eq 0 ]
  [[ "$output" == *"false"* ]]

  run _config_value autoOpenBrowser
  [ "$status" -eq 0 ]
  [[ "$output" == *"false"* ]]
}

@test "backlog config keeps auditability and hooks enabled" {
  # auto_commit is deliberately FALSE: board transitions commit WITH their related
  # code as one coherent dependency-oriented unit (not separate "Update task"
  # noise), and this avoids task-markdown conflicts during worktree fan-out.
  # Auditability is preserved by those coherent commits + enabled git hooks, not
  # by per-edit auto-commits. See docs/backlog.md §1.1 / §5. Guards against drift
  # back to auto_commit=true.
  run _config_value autoCommit
  [ "$status" -eq 0 ]
  [[ "$output" == *"false"* ]]

  run _config_value bypassGitHooks
  [ "$status" -eq 0 ]
  [[ "$output" == *"false"* ]]
}

@test "backlog config exposes the zdots triage label vocabulary" {
  run _config_value labels
  [ "$status" -eq 0 ]
  for label in agent-reported bug question request needs-info agent-ready; do
    [[ "$output" == *"$label"* ]] || {
      echo "missing label: $label"
      return 1
    }
  done
}

@test "ztask delegates task status edits to backlog CLI" {
  ! grep -qE 'sed -i.*Status|sed -i.*status' "$REPO_ROOT/bin/ztask"
  grep -q 'task edit "$id" --status "$status" --plain' "$REPO_ROOT/bin/ztask"
}
