#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  ZD="$REPO_ROOT/bin/zdots"
}

@test "zdots --help, -h, and bare invocation succeed and list nouns" {
  run "$ZD" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: zdots <noun> [verb] [args...]"* ]]
  [[ "$output" == *"status"* ]]

  run "$ZD" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: zdots <noun> [verb] [args...]"* ]]

  run "$ZD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: zdots <noun> [verb] [args...]"* ]]
}

@test "zdots --help handles empty or missing ZDOTDIR without glob error" {
  run env ZDOTDIR="$BATS_TEST_TMPDIR/nonexistent" "$ZD" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: zdots <noun> [verb] [args...]"* ]]
  [[ "$output" != *"no matches found"* ]]
}

@test "zdots dispatches to zdots-<noun> with args and exit status even without ZDOTDIR/bin in PATH" {
  local tmp_zdot="$BATS_TEST_TMPDIR/zdot"
  mkdir -p "$tmp_zdot/bin"
  cat > "$tmp_zdot/bin/zdots-echo" <<'EOF'
#!/usr/bin/env bash
printf 'args:%s\n' "$*"
exit 42
EOF
  chmod +x "$tmp_zdot/bin/zdots-echo"

  run env ZDOTDIR="$tmp_zdot" PATH="/usr/bin:/bin" "$ZD" echo one two
  [ "$status" -eq 42 ]
  [ "$output" = "args:one two" ]
}

@test "zdots unknown noun exits 1 and suggests matching nouns" {
  run "$ZD" stat
  [ "$status" -eq 1 ]
  [[ "$output" == *'zdots: unknown noun "stat"'* ]]
  [[ "$output" == *"did you mean: zdots status"* ]]
}

@test "zdots rejects nouns containing a slash" {
  local tmp_zdot="$BATS_TEST_TMPDIR/zdot_slash"
  mkdir -p "$tmp_zdot/bin/zdots-sub"
  cat > "$tmp_zdot/bin/zdots-sub/cmd" <<'EOF'
#!/usr/bin/env bash
echo "should not run"
EOF
  chmod +x "$tmp_zdot/bin/zdots-sub/cmd"

  run env ZDOTDIR="$tmp_zdot" "$ZD" sub/cmd
  [ "$status" -eq 1 ]
  [[ "$output" == *'zdots: unknown noun "sub/cmd"'* ]]
  [[ "$output" != *"should not run"* ]]
}

@test "zdots shell function cds to ZDOTDIR on TTY with no args outside ZDOTDIR" {
  run script -q /dev/null env ZDOTDIR="$REPO_ROOT" zsh -c '
    source "$ZDOTDIR/conf.d/40-completion.zsh"
    cd /tmp
    zdots
    pwd -P
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(cd "$REPO_ROOT" && pwd -P)"* ]]
}

@test "zdots shell function delegates when piped, given args, or already in ZDOTDIR" {
  run env ZDOTDIR="$REPO_ROOT" zsh -c '
    source "$ZDOTDIR/conf.d/40-completion.zsh"
    cd /tmp
    out="$(zdots | head -n 1)"
    echo "piped_pwd=$(pwd -P)"
    echo "piped_out=$out"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"piped_pwd=$(cd /tmp && pwd -P)"* ]]
  [[ "$output" == *"piped_out=usage: zdots <noun> [verb] [args...]"* ]]

  run script -q /dev/null env ZDOTDIR="$REPO_ROOT" zsh -c '
    source "$ZDOTDIR/conf.d/40-completion.zsh"
    cd /tmp
    zdots --help | head -n 1
    echo "arg_pwd=$(pwd -P)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"arg_pwd=$(cd /tmp && pwd -P)"* ]]
  [[ "$output" == *"usage: zdots <noun> [verb] [args...]"* ]]

  run script -q /dev/null env ZDOTDIR="$REPO_ROOT" zsh -c '
    source "$ZDOTDIR/conf.d/40-completion.zsh"
    cd "$ZDOTDIR"
    zdots | head -n 1 >/dev/null
    zdots
    echo "survived_in_zdotdir=1"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: zdots <noun> [verb] [args...]"* ]]
  [[ "$output" == *"survived_in_zdotdir=1"* ]]
}
