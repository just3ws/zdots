#!/usr/bin/env bats
# tests/completions.bats — every zdots command completes. Dedicated _<cmd>
# completions keep theirs; the rest get _gnu_generic (options from --help).
# Docs-contract known gaps get none: completing them would run their "--help",
# which for them is a real invocation.

setup() {
  load "setup.bash"
  setup_environment
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

@test "every completion file parses" {
  for f in "$REPO_ROOT"/functions/enabled/_*; do
    zsh -n "$f"
  done
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
