#!/usr/bin/env bats
# tests/ztask_e2e.bats — live task-orchestrator health checks.
#
# This proves ztask end-to-end without depending on OTel: task activation,
# active-task state, platform readiness, and Brain hydration readiness.
#
# Run: bats tests/ztask_e2e.bats

setup_file() {
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export ZDOTDIR="$REPO_ROOT"
  export ZTASK="$REPO_ROOT/bin/ztask"
  export ACTIVE_TASK_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/active_task"
  export ACTIVE_TASK_BACKUP="$BATS_FILE_TMPDIR/active_task.backup"

  mkdir -p "$(dirname "$ACTIVE_TASK_FILE")"
  if [[ -f "$ACTIVE_TASK_FILE" ]]; then
    cp "$ACTIVE_TASK_FILE" "$ACTIVE_TASK_BACKUP"
  else
    rm -f "$ACTIVE_TASK_BACKUP"
  fi
}

teardown_file() {
  if [[ -f "$ACTIVE_TASK_BACKUP" ]]; then
    mkdir -p "$(dirname "$ACTIVE_TASK_FILE")"
    cp "$ACTIVE_TASK_BACKUP" "$ACTIVE_TASK_FILE"
  else
    rm -f "$ACTIVE_TASK_FILE"
  fi
}

setup() {
  load "setup.bash"
  setup_environment
}

_have_task() {
  compgen -G "$REPO_ROOT/backlog/tasks/z-120*" >/dev/null
}

@test "ztask health --json reports orchestration dependencies" {
  run "$ZTASK" health --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .healthy == true and
    .tasks_dir == true and
    .backlog_cli == true and
    .platform_ready == true and
    .brain_ready == true and
    .hydration_ready == true
  ' >/dev/null
}

@test "ztask start hydrates a task and health sees active state" {
  _have_task || skip "z-120 task not present"

  run "$ZTASK" start z-120
  [ "$status" -eq 0 ]
  [[ "$output" == *"hydrating task context"* ]]
  [[ "$output" == *"task z-120 active"* ]]

  run "$ZTASK" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active task: z-120"* ]]

  run "$ZTASK" health --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .healthy == true and
    .active_task == "z-120" and
    .active_task_valid == true and
    (.active_task_file | contains("z-120"))
  ' >/dev/null
}

@test "ztask stop clears active task without breaking health" {
  run "$ZTASK" stop
  [ "$status" -eq 0 ]

  run "$ZTASK" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no active task"* ]]

  run "$ZTASK" health --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .healthy == true and
    .active_task == null and
    .active_task_valid == true
  ' >/dev/null
}
