#!/usr/bin/env bats
# tests/local_bin_path.bats — conf.d/08-local-bin.zsh chpwd hook (Z-338).
#
# WHAT: the hook prepends $PWD/bin on cd, removes ONLY what it added on the
# way out, and never evicts a $PWD/bin that was already on PATH (a "sticky"
# dir put there by env.sh / .zshrc.local — e.g. ~/.config/nvim/bin).

HOOK="${BATS_TEST_DIRNAME}/../conf.d/08-local-bin.zsh"

# Drive the hook through a scripted cd sequence in a real zsh and print the
# resulting PATH. $1 = sticky dir to seed onto PATH ("" for none), rest = dirs
# to cd through in order.
run_hook() {
  local sticky="$1"; shift
  local script cds="" d
  for d in "$@"; do
    cds+="cd '$d' 2>/dev/null; _zdots_chpwd_local_bin"$'\n'
  done
  script="autoload -Uz add-zsh-hook
typeset -U path"
  [ -n "$sticky" ] && script+=$'\n'"path=('$sticky' \$path)"
  script+="
source '$HOOK'
add-zsh-hook -d precmd _zdots_prime_local_bin
$cds
print -rn -- \$PATH"
  zsh -df -c "$script"
}

setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/repo-a/bin" "$TMP/repo-b/bin" "$TMP/plain"
}

teardown() { rm -rf "$TMP"; }

@test "prepends ./bin when entering a dir that has one" {
  run run_hook "" "$TMP/repo-a"
  [ "$status" -eq 0 ]
  [[ "$output" == "$TMP/repo-a/bin:"* ]]
}

@test "removes its own entry when leaving for a plain dir" {
  run run_hook "" "$TMP/repo-a" "$TMP/plain"
  [ "$status" -eq 0 ]
  [[ "$output" != *"$TMP/repo-a/bin"* ]]
}

@test "swaps cleanly between two repo bins" {
  run run_hook "" "$TMP/repo-a" "$TMP/repo-b"
  [ "$status" -eq 0 ]
  [[ "$output" == "$TMP/repo-b/bin:"* ]]
  [[ "$output" != *"$TMP/repo-a/bin"* ]]
}

@test "does NOT evict a sticky ./bin when leaving that repo (Z-338)" {
  run run_hook "$TMP/repo-a/bin" "$TMP/repo-a" "$TMP/plain"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TMP/repo-a/bin"* ]]
}

@test "sticky ./bin survives a round trip through another repo" {
  run run_hook "$TMP/repo-a/bin" "$TMP/repo-a" "$TMP/repo-b" "$TMP/plain"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TMP/repo-a/bin"* ]]
  [[ "$output" != *"$TMP/repo-b/bin"* ]]
}

@test "no duplicate entries after repeated entry" {
  run run_hook "" "$TMP/repo-a" "$TMP/plain" "$TMP/repo-a"
  [ "$status" -eq 0 ]
  [[ "$(tr ':' '\n' <<<"$output" | grep -c "^$TMP/repo-a/bin$")" == "1" ]]
}
