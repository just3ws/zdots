#!/usr/bin/env bats
# tests/zdots_version.bats — tests for zdots --version and zdots-version self-validation.

setup() {
  load "setup.bash"
  setup_environment

  export FAKE_ROOT="$BATS_TEST_TMPDIR/env"
  export ZDOTDIR="$FAKE_ROOT/zsh"
  export HOME="$FAKE_ROOT/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  unset ZDOTS_SURFACES_FILE
  export ZDOTS_ADOTS_VERSION="$HOME/VERSION"
  export ZDOTS_ZTRANSCRIBE_ROOT="$HOME/github.com/just3ws/ztranscribe"
  export MEDIA_PIPELINE_ROOT="$HOME/github.com/just3ws/media-pipeline"
  export JUST3WS_SITE_ROOT="$HOME/github.com/just3ws/just3ws.github.io"

  mkdir -p \
    "$ZDOTDIR/bin" \
    "$XDG_CONFIG_HOME/nvim" \
    "$HOME/my" \
    "$ZDOTS_ZTRANSCRIBE_ROOT" \
    "$MEDIA_PIPELINE_ROOT" \
    "$JUST3WS_SITE_ROOT"

  cp "$REPO_ROOT/bin/zdots" "$ZDOTDIR/bin/zdots"
  cp "$REPO_ROOT/bin/zdots-version" "$ZDOTDIR/bin/zdots-version"
  cp "$REPO_ROOT/bin/imperial-date" "$ZDOTDIR/bin/imperial-date"
  chmod +x "$ZDOTDIR/bin/zdots" "$ZDOTDIR/bin/zdots-version" "$ZDOTDIR/bin/imperial-date"

  printf '0879026.M3\n' >"$ZDOTDIR/VERSION"
  printf '0879026.M3\n' >"$ZDOTS_ADOTS_VERSION"
  printf '0879026.M3\n' >"$XDG_CONFIG_HOME/nvim/VERSION"
  printf '0879026.M3\n' >"$HOME/my/VERSION"
  printf '0879026.M3\n' >"$ZDOTS_ZTRANSCRIBE_ROOT/VERSION"
  printf '0879026.M3\n' >"$MEDIA_PIPELINE_ROOT/VERSION"
  printf '0879026.M3\n' >"$JUST3WS_SITE_ROOT/VERSION"
}

@test "zdots --version prints the Astronomicon beacon" {
  run "$ZDOTDIR/bin/zdots" --version
  [ "$status" -eq 0 ]
  [ "$output" = "0879026.M3" ]
}

@test "zdots version check passes when all core surfaces are aligned" {
  run "$ZDOTDIR/bin/zdots" version check
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ok]     zdots              0879026.M3"* ]]
  [[ "$output" == *"[ok]     vdots              0879026.M3"* ]]
}

@test "zdots --version --check fails on surface drift" {
  printf '0873026.M3\n' >"$XDG_CONFIG_HOME/nvim/VERSION"
  run "$ZDOTDIR/bin/zdots" --version --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"[drift]  vdots              0873026.M3 (expected 0879026.M3)"* ]]
}

@test "zdots-version --check --strict fails when a surface is absent" {
  rm -f "$XDG_CONFIG_HOME/nvim/VERSION"
  run "$ZDOTDIR/bin/zdots-version" --check
  [ "$status" -eq 0 ]

  run "$ZDOTDIR/bin/zdots-version" --check --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"[absent] vdots"* ]]
}

@test "zdots-version --check fails on malformed beacon" {
  printf 'not-imperial\n' >"$ZDOTDIR/VERSION"
  run "$ZDOTDIR/bin/zdots-version" --check
  [ "$status" -eq 1 ]
}

@test "zdots-version align stamps all core surfaces and passes check" {
  printf '0873026.M3\n' >"$ZDOTDIR/VERSION"
  printf '0873026.M3\n' >"$XDG_CONFIG_HOME/nvim/VERSION"

  run "$ZDOTDIR/bin/zdots-version" align 0880026.M3
  [ "$status" -eq 0 ]

  run "$ZDOTDIR/bin/zdots-version" --check --strict
  [ "$status" -eq 0 ]
  run "$ZDOTDIR/bin/zdots" --version
  [ "$output" = "0880026.M3" ]
}

@test "zdots-version --json emits valid JSON with aligned status" {
  run "$ZDOTDIR/bin/zdots-version" --json
  [ "$status" -eq 0 ]
  run jq -e '.beacon == "0879026.M3" and .aligned == true and (.surfaces | length) == 3' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "zdots-version honours ZDOTS_SURFACES_FILE without requiring my" {
  rm -rf "$HOME/my" "$ZDOTS_ZTRANSCRIBE_ROOT" "$MEDIA_PIPELINE_ROOT" "$JUST3WS_SITE_ROOT"
  local manifest="$BATS_TEST_TMPDIR/surfaces.conf"
  cat >"$manifest" <<'EOF'
# Minimal deployed host (no personal vault or media repos)
zdots	$ZDOTDIR/VERSION	git
adots	$HOME/VERSION	bare:$HOME/.homegit
EOF

  ZDOTS_SURFACES_FILE="$manifest" run "$ZDOTDIR/bin/zdots-version" --check --strict --json
  [ "$status" -eq 0 ]
  run jq -e '.aligned == true and (.surfaces | length) == 2 and (.surfaces | map(.name) == ["zdots", "adots"])' <<<"$output"
  [ "$status" -eq 0 ]
}
