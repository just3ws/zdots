#!/usr/bin/env bats
# tests/adots_my_structure.bats — adots-my generator and migration contract.

setup() {
  load "setup.bash"
  setup_environment
  ADOTS_MY="/Users/mike/bin/adots-my"
}

setup_my_repo() {
  MY_ROOT="$BATS_TEST_TMPDIR/my"
  mkdir -p "$MY_ROOT"
  git -C "$MY_ROOT" init -q
  git -C "$MY_ROOT" config user.name "Codex Test"
  git -C "$MY_ROOT" config user.email "codex@example.com"
  git -C "$MY_ROOT" remote add origin https://github.com/just3ws/my.git
}

@test "adots-my prepare dry-run reports the planned skeleton without mutating" {
  setup_my_repo
  out="$BATS_TEST_TMPDIR/prepare-dry-run.out"
  status_file="$BATS_TEST_TMPDIR/prepare-dry-run.status"

  if "$ADOTS_MY" prepare --dry-run --my-root "$MY_ROOT" >"$out" 2>&1; then
    my_status=0
  else
    my_status=$?
  fi
  printf "%s" "$my_status" >"$status_file"

  [ "$my_status" -eq 0 ]
  [ "$(cat "$status_file")" = "0" ]
  grep -F "would create dir" "$out" >/dev/null
  grep -F "would write file" "$out" >/dev/null
  [ ! -e "$MY_ROOT/config" ]
  [ ! -e "$MY_ROOT/vaults/public" ]
}

@test "adots-my prepare apply creates the safe skeleton and sources template" {
  setup_my_repo
  out="$BATS_TEST_TMPDIR/prepare-apply.out"
  status_file="$BATS_TEST_TMPDIR/prepare-apply.status"

  if "$ADOTS_MY" prepare --apply --my-root "$MY_ROOT" >"$out" 2>&1; then
    my_status=0
  else
    my_status=$?
  fi
  printf "%s" "$my_status" >"$status_file"

  [ "$my_status" -eq 0 ]
  [ "$(cat "$status_file")" = "0" ]
  [ -d "$MY_ROOT/.archive" ]
  [ -d "$MY_ROOT/config" ]
  [ -d "$MY_ROOT/docs/migrations" ]
  [ -d "$MY_ROOT/context-engine" ]
  [ -d "$MY_ROOT/knowledge/inbox" ]
  [ -d "$MY_ROOT/vaults/personal" ]
  [ -d "$MY_ROOT/vaults/public" ]
  [ -f "$MY_ROOT/config/sources.yml" ]
  grep -F "my.context_engine" "$MY_ROOT/config/sources.yml" >/dev/null
  grep -F "my.vault.personal" "$MY_ROOT/config/sources.yml" >/dev/null
}

@test "adots-my migrate apply archives legacy roots and writes a migration note" {
  setup_my_repo
  mkdir -p "$MY_ROOT/backlog" "$MY_ROOT/lessons" "$MY_ROOT/_archive"
  printf 'legacy backlog\n' > "$MY_ROOT/backlog/note.txt"
  printf 'legacy lessons\n' > "$MY_ROOT/lessons/note.txt"
  printf 'legacy archive\n' > "$MY_ROOT/_archive/legacy.txt"
  out="$BATS_TEST_TMPDIR/migrate-apply.out"
  status_file="$BATS_TEST_TMPDIR/migrate-apply.status"

  if "$ADOTS_MY" migrate --apply --my-root "$MY_ROOT" >"$out" 2>&1; then
    my_status=0
  else
    my_status=$?
  fi
  printf "%s" "$my_status" >"$status_file"

  [ "$my_status" -eq 0 ]
  [ "$(cat "$status_file")" = "0" ]
  [ ! -e "$MY_ROOT/backlog" ]
  [ ! -e "$MY_ROOT/lessons" ]
  [ ! -e "$MY_ROOT/_archive" ]
  [ -f "$MY_ROOT/.archive/backlog/note.txt" ]
  [ -f "$MY_ROOT/.archive/lessons/note.txt" ]
  [ -f "$MY_ROOT/.archive/_archive/legacy.txt" ]
  [ -f "$MY_ROOT/docs/migrations/my.structure.migration.v1.md" ]
  grep -F "backlog -> .archive/backlog" "$MY_ROOT/docs/migrations/my.structure.migration.v1.md" >/dev/null
}
