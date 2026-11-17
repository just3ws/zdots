#!/usr/bin/env bats
# tests/completions.bats — structural gate for functions/enabled/_* (Z-233).
#
# WHAT: every completion file parses clean and declares its command.
# WHY: the old command-qc gate SOURCED the files, which executes the trailing
# `_<cmd> "$@"` outside compsys — _arguments always errors there and the exit
# code was just whichever statement ran last. Parse-only is the honest signal.
#
# Coverage: every zdots command completes. Dedicated _<cmd> completions keep
# theirs; the rest get _gnu_generic (options from --help). Docs-contract known
# gaps get none: completing them would run their "--help", which for them is a
# real invocation.

ZDOTS="${BATS_TEST_DIRNAME}/.."

setup() {
  load "setup.bash"
  setup_environment
}

@test "completions: every file parses (zsh -n)" {
  for f in "$ZDOTS"/functions/enabled/_*; do
    run zsh -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failure: $f"; return 1; }
  done
}

@test "completions: every file opens with a #compdef header" {
  for f in "$ZDOTS"/functions/enabled/_*; do
    run head -1 "$f"
    [[ "$output" == "#compdef"* ]] || { echo "missing #compdef: $f"; return 1; }
  done
}

_comps_for_bin() {
  zsh -f -c '
    ZDOTDIR="'"$REPO_ROOT"'"
    HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
    XDG_CACHE_HOME="'"$BATS_TEST_TMPDIR"'/cache"
    source "$ZDOTDIR/conf.d/40-completion.zsh"
    for f in "$ZDOTDIR"/bin/*(-.x); do print -r -- "${f:t} ${_comps[${f:t}]:--}"; done
  '
}

@test "every zdots command has a completion, except known gaps" {
  run _comps_for_bin
  [ "$status" -eq 0 ]
  gaps="$(grep -v '^#' "$REPO_ROOT/docs/generated/docs-contract-known-gaps.txt" | cut -d: -f1)"
  missing=""
  while read -r cmd comp; do
    [[ "$cmd" == *.py || "$cmd" == *.rb ]] && continue
    grep -qx "$cmd" <<<"$gaps" && continue
    [[ "$comp" != "-" ]] || missing="$missing $cmd"
  done <<<"$output"
  [[ -z "$missing" ]] || { echo "no completion:$missing" >&2; return 1; }
}

@test "known-gap commands get no generic completion" {
  run _comps_for_bin
  gaps="$(grep -v '^#' "$REPO_ROOT/docs/generated/docs-contract-known-gaps.txt" | cut -d: -f1)"
  while read -r cmd comp; do
    grep -qx "$cmd" <<<"$gaps" || continue
    [[ "$comp" != "_gnu_generic" ]] || { echo "$cmd would run on TAB" >&2; return 1; }
  done <<<"$output"
}

@test "dedicated completions are kept" {
  run _comps_for_bin
  grep -qx 'zdots-ctl _zdots-ctl' <<<"$output"
  grep -qx 'zsvc _zsvc' <<<"$output"
}
