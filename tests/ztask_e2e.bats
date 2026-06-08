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
  export ZTASK_TEST_ROOT="$BATS_FILE_TMPDIR/ztask"
  export ZTASK_TEST_TASKS="$ZTASK_TEST_ROOT/tasks"
  export ZTASK_TEST_ACTIVE="$ZTASK_TEST_ROOT/active_task"
  export ZTASK_TEST_BIN="$ZTASK_TEST_ROOT/bin"
  export ZTASK_TEST_LOG="$ZTASK_TEST_ROOT/calls.log"

  mkdir -p "$(dirname "$ACTIVE_TASK_FILE")"
  if [[ -f "$ACTIVE_TASK_FILE" ]]; then
    cp "$ACTIVE_TASK_FILE" "$ACTIVE_TASK_BACKUP"
  else
    rm -f "$ACTIVE_TASK_BACKUP"
  fi

  mkdir -p "$ZTASK_TEST_TASKS" "$ZTASK_TEST_BIN"
  cat > "$ZTASK_TEST_TASKS/z-999 - isolated-proof.md" <<'TASK'
---
id: Z-999
title: Isolated ztask proof
status: To Do
priority: Medium
---

## Description
Temporary ztask E2E fixture.
TASK
  cat > "$ZTASK_TEST_BIN/backlog" <<'BACKLOG'
#!/usr/bin/env bash
set -euo pipefail
printf 'backlog %s\n' "$*" >> "${ZTASK_TEST_LOG:?}"
if [[ "${1:-}" == "task" && "${2:-}" == "edit" ]]; then
  id="$3"; shift 3
  status=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status="$2"; shift 2 ;;
      --plain) shift ;;
      *) shift ;;
    esac
  done
  file=$(ls "${ZTASK_TASKS_DIR:?}"/"$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"* 2>/dev/null | head -n 1)
  [[ -n "$file" ]]
  if [[ -n "$status" ]]; then
    sed -i '' -E "s/^status: .*/status: ${status}/" "$file"
  fi
  printf 'edited %s -> %s\n' "$id" "$status"
  exit 0
fi
exit 1
BACKLOG
  chmod +x "$ZTASK_TEST_BIN/backlog"
  cat > "$ZTASK_TEST_BIN/zdots-ctl" <<'CTL'
#!/usr/bin/env bash
set -euo pipefail
printf 'zdots-ctl %s\n' "$*" >> "${ZTASK_TEST_LOG:?}"
case "${1:-}" in
  up) exit 0 ;;
  status)
    if [[ "${2:-}" == "--json" ]]; then
      printf '{"colima":true,"lgtm":true,"otel_collector":true,"ai_server":true,"embed_server":true,"intelligence_suite":true,"cache":true}\n'
      exit 0
    fi ;;
esac
exit 1
CTL
  chmod +x "$ZTASK_TEST_BIN/zdots-ctl"
  cat > "$ZTASK_TEST_BIN/zdots-ctx" <<'CTX'
#!/usr/bin/env bash
set -euo pipefail
printf 'zdots-ctx %s\n' "$*" >> "${ZTASK_TEST_LOG:?}"
case "${1:-}" in
  status) printf 'connected to database: my\n'; exit 0 ;;
  hydrate) printf 'hydrated %s\n' "${2:-}"; exit 0 ;;
  capture) printf 'captured\n'; exit 0 ;;
esac
exit 1
CTX
  chmod +x "$ZTASK_TEST_BIN/zdots-ctx"
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

_ztask_isolated() {
  env \
    ZTASK_TASKS_DIR="$ZTASK_TEST_TASKS" \
    ZTASK_ACTIVE_TASK_FILE="$ZTASK_TEST_ACTIVE" \
    ZTASK_BACKLOG_BIN="$ZTASK_TEST_BIN/backlog" \
    ZTASK_ZDOTS_CTL="$ZTASK_TEST_BIN/zdots-ctl" \
    ZTASK_ZDOTS_CTX="$ZTASK_TEST_BIN/zdots-ctx" \
    ZTASK_TEST_LOG="$ZTASK_TEST_LOG" \
    "$ZTASK" "$@"
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

@test "ztask start uses backlog CLI, hydrates a task, and health sees active state" {
  skip_in_ci
  run _ztask_isolated start z-999
  [ "$status" -eq 0 ]
  [[ "$output" == *"hydrating task context"* ]]
  [[ "$output" == *"hydrated z-999"* ]]
  [[ "$output" == *"task z-999 active"* ]]
  grep -q 'backlog task edit z-999 --status In Progress --plain' "$ZTASK_TEST_LOG"
  grep -q 'zdots-ctl up' "$ZTASK_TEST_LOG"
  grep -q 'zdots-ctx hydrate z-999' "$ZTASK_TEST_LOG"
  grep -q '^status: In Progress$' "$ZTASK_TEST_TASKS/z-999 - isolated-proof.md"

  run _ztask_isolated status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active task: z-999"* ]]

  run _ztask_isolated health --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .healthy == true and
    .active_task == "z-999" and
    .active_task_valid == true and
    (.active_task_file | contains("z-999"))
  ' >/dev/null
}

@test "ztask done uses backlog CLI and clears active state" {
  run _ztask_isolated done
  [ "$status" -eq 0 ]
  [[ "$output" == *"captured"* ]]
  [[ "$output" == *"task z-999 completed"* ]]
  grep -q 'backlog task edit z-999 --status Done --plain' "$ZTASK_TEST_LOG"
  grep -q 'zdots-ctx capture' "$ZTASK_TEST_LOG"
  grep -q '^status: Done$' "$ZTASK_TEST_TASKS/z-999 - isolated-proof.md"

  run _ztask_isolated status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no active task"* ]]
}

@test "ztask stop clears active task without breaking health" {
  skip_in_ci
  run _ztask_isolated stop
  [ "$status" -eq 0 ]

  run _ztask_isolated status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no active task"* ]]

  run _ztask_isolated health --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .healthy == true and
    .active_task == null and
    .active_task_valid == true
  ' >/dev/null
}
