#!/usr/bin/env bats
# tests/man_pages.bats — man pages lint clean, carry no terminal control
# characters or host paths, and zdots-man-gen never runs a command that has no
# safe --help (docs-contract known gaps) to fill one in.

setup() {
  load "setup.bash"
  setup_environment
}

@test "every man page lints clean with mandoc (errors fail)" {
  # mandoc ships with macOS; missing means a broken host, not a reason to skip.
  command -v mandoc >/dev/null 2>&1 || { echo "mandoc not found (macOS ships it at /usr/bin/mandoc)" >&2; return 1; }
  local bad=""
  while IFS= read -r page; do
    out="$(mandoc -Tlint -W error "$page" 2>&1)" || bad="$bad\n$out"
    [[ -z "$out" ]] || bad="$bad\n$out"
  done < <(find "$REPO_ROOT/man" -type f | sort)
  [[ -z "$bad" ]] || { printf '%b\n' "$bad" >&2; return 1; }
}

@test "no man page contains terminal control characters or a home path" {
  run grep -rlE $'[\x01-\x08\x0b\x0c\x0e-\x1f]|/Users/[a-z]|/home/[a-z]' "$REPO_ROOT/man"
  [ "$status" -eq 1 ]
}

@test "zdots-man-gen never runs a known-gap command and strips control characters" {
  fake="$BATS_TEST_TMPDIR/zdots"
  mark="$BATS_TEST_TMPDIR/ran"
  mkdir -p "$fake/bin" "$fake/man/man1" "$fake/docs/generated"
  cp "$REPO_ROOT/bin/zdots-man-gen" "$fake/bin/"
  printf '#!/bin/sh\necho ran >>"%s"\n' "$mark" >"$fake/bin/sidefx"
  printf '#!/bin/sh\nprintf "Usage: noisy\\n\\033]1337;CurrentDir=/Users/someone\\007colour \\033[31mred\\033[0m\\n"\n' >"$fake/bin/noisy"
  chmod +x "$fake/bin/"*
  printf 'sidefx: acts on any invocation; no --help contract z-119\n' >"$fake/docs/generated/docs-contract-known-gaps.txt"
  ZDOTDIR="$fake" run "$fake/bin/zdots-man-gen"
  [ "$status" -eq 0 ]
  [ ! -e "$mark" ]
  [ -s "$fake/man/man1/sidefx.1" ]
  ! grep -qE $'[\x01-\x08\x0b\x0c\x0e-\x1f]|/Users/|'"$HOME" "$fake/man/man1/noisy.1"
  grep -q 'colour red' "$fake/man/man1/noisy.1"
}
