#!/usr/bin/env bats
# tests/env_posix.bats — Verify POSIX compliance of env.sh

setup() {
  load "setup.bash"
  setup_environment
}

@test "env.sh: Sets XDG base directories" {
  # Run in a clean subshell (using bash for POSIX-like check)
  run bash -c "export ZDOTDIR=$ZDOTDIR; . $ZDOTDIR/env.sh && echo \$XDG_CONFIG_HOME"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  # Get last line to avoid noise
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$HOME/.config" ]
}

@test "env.sh: Sets ZDOTDIR if not provided" {
  # We unset ZDOTDIR inside the subshell to test fallback
  run bash -c "unset ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTDIR"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$HOME/.config/zsh" ]
}

@test "env.sh: Correctly handles ZDOTS_ENV_PROFILE=ci-act" {
  run bash -c "export ZDOTDIR=$ZDOTDIR; export ZDOTS_ENV_PROFILE=ci-act; . $ZDOTDIR/env.sh && echo \$HOMEBREW_PREFIX"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  
  if [ "$(uname -s)" = "Darwin" ]; then
    # On Darwin, ci-act now allows homebrew to satisfy yq/bats dependencies
    [ -n "$val" ]
    [[ "$val" == "/opt/homebrew" || "$val" == "/usr/local" ]]
  else
    [ "$val" == "" ]
  fi
}

@test "env.sh: Sources under nounset when CI variables are absent" {
  run bash -u -c "export ZDOTDIR=$ZDOTDIR; unset CI GITHUB_ACTIONS ACT; . $ZDOTDIR/env.sh && echo ok"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "ok" ]
}

@test "env.sh: Selects Brewfile.home by default" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-home; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; export ZDOTDIR=\"\$tmp\"; unset ZDOTS_CONTEXT HOMEBREW_BUNDLE_FILE; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-home/Brewfile.home" ]
}

@test "env.sh: Selects Brewfile.work for work context" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-work; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; cp \"\$repo/.zdots.work\" \"\$tmp/.zdots.work\"; printf 'ZDOTS_CONTEXT=work\n' > \"\$tmp/.zdots.local\"; export ZDOTDIR=\"\$tmp\"; unset HOMEBREW_BUNDLE_FILE; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-work/Brewfile.work" ]
}

@test "env.sh: Work posture overrides unsafe machine-local settings" {
  local fixture="$BATS_TEST_TMPDIR/work-posture"
  mkdir -p "$fixture"
  cp "$ZDOTDIR/.zdots.work" "$fixture/.zdots.work"
  cat > "$fixture/.zdots.local" <<'EOF'
ZDOTS_CONTEXT=work
ZDOTS_CAPTURE_ENABLED=1
ZDOTS_CMD_ANALYTICS=1
ZDOTS_HISTORY_REDACT=0
ZDOTS_AI_MODE=cloud
EOF

  # No baseline, secrets, Keychain library, or providers in this fresh fixture.
  run bash -c '
    export ZDOTDIR="$1"
    . "$2/env.sh"
    printf "%s %s %s %s %s\n" "$ZDOTS_CONTEXT" "$ZDOTS_CAPTURE_ENABLED" \
      "$ZDOTS_CMD_ANALYTICS" "$ZDOTS_HISTORY_REDACT" "$ZDOTS_AI_MODE"
  ' _ "$fixture" "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "work 0 0 1 local" ]
}

@test "work profile: preserves explicitly disabled AI" {
  run bash -c 'ZDOTS_AI_MODE=none; . "$1/.zdots.work"; printf "%s\n" "$ZDOTS_AI_MODE"' _ "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "$output" == "none" ]
}

@test "env.sh: Replaces stale naked Brewfile setting" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-stale; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; cp \"\$repo/.zdots.work\" \"\$tmp/.zdots.work\"; printf 'ZDOTS_CONTEXT=work\n' > \"\$tmp/.zdots.local\"; export ZDOTDIR=\"\$tmp\"; export HOMEBREW_BUNDLE_FILE=\"\$tmp/Brewfile\"; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-stale/Brewfile.work" ]
}

@test "env.sh: Replaces inherited managed home Brewfile on work context" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-managed; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; cp \"\$repo/.zdots.work\" \"\$tmp/.zdots.work\"; printf 'ZDOTS_CONTEXT=work\n' > \"\$tmp/.zdots.local\"; export ZDOTDIR=\"\$tmp\"; export HOMEBREW_BUNDLE_FILE=\"\$tmp/Brewfile.home\"; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-managed/Brewfile.work" ]
}

@test "env.sh: Generates a 32-hex W3C Trace ID" {
  run bash -c "export ZDOTDIR=$ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTS_TRACE_ID"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [[ "$val" =~ ^[0-9a-f]{32}$ ]]
}

@test "env.sh: Generates a 16-hex W3C Span ID" {
  run bash -c "export ZDOTDIR=$ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTS_SPAN_ID"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [[ "$val" =~ ^[0-9a-f]{16}$ ]]
}

@test "env.sh: keeps path_helper system paths such as /usr/local/bin on macOS" {
  [ -x /usr/libexec/path_helper ] || skip "path_helper is macOS-only"
  run bash -c '
    export ZDOTDIR="$1"; . "$1/env.sh" >/dev/null 2>&1
    case ":$PATH:" in *":/usr/local/bin:"*) echo present ;; *) echo missing ;; esac
  ' _ "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "present" ]
}

@test "env.sh: a legacy-only ~/.aws or ~/.docker is not hidden by the XDG redirect" {
  local home="$BATS_TEST_TMPDIR/legacy-home"
  mkdir -p "$home/.aws" "$home/.docker"
  run env -u XDG_ROOT -u XDG_CONFIG_HOME HOME="$home" bash -c '
    export ZDOTDIR="$1"; . "$1/env.sh" >/dev/null 2>&1
    echo "${AWS_CONFIG_FILE-unset} ${DOCKER_CONFIG-unset}"
  ' _ "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "unset unset" ]
}

@test "env.sh: XDG redirects for AWS and Docker apply once the XDG root exists" {
  local home="$BATS_TEST_TMPDIR/xdg-home"
  mkdir -p "$home/.config/aws" "$home/.config/docker" "$home/.aws" "$home/.docker"
  run env -u XDG_ROOT -u XDG_CONFIG_HOME HOME="$home" bash -c '
    export ZDOTDIR="$1"; . "$1/env.sh" >/dev/null 2>&1
    echo "$AWS_CONFIG_FILE $DOCKER_CONFIG"
  ' _ "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "$home/.config/aws/config $home/.config/docker" ]
}

@test "env.sh: work-context relative PATH entries stay on by default" {
  local fixture="$BATS_TEST_TMPDIR/work-relpath-default"
  mkdir -p "$fixture"
  cp "$ZDOTDIR/.zdots.env" "$ZDOTDIR/.zdots.work" "$fixture/"
  printf 'ZDOTS_CONTEXT=work\n' > "$fixture/.zdots.local"
  run bash -c '
    export ZDOTDIR="$1"; unset ZDOTS_WORK_RELATIVE_PATH; . "$2/env.sh" >/dev/null 2>&1
    case ":$PATH:" in *":./bin:"*) echo present ;; *) echo absent ;; esac
  ' _ "$fixture" "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "present" ]
}

@test "env.sh: ZDOTS_WORK_RELATIVE_PATH=0 drops work-context relative PATH entries" {
  local fixture="$BATS_TEST_TMPDIR/work-relpath-off"
  mkdir -p "$fixture"
  cp "$ZDOTDIR/.zdots.env" "$ZDOTDIR/.zdots.work" "$fixture/"
  printf 'ZDOTS_CONTEXT=work\nZDOTS_WORK_RELATIVE_PATH=0\n' > "$fixture/.zdots.local"
  run bash -c '
    export ZDOTDIR="$1"; . "$2/env.sh" >/dev/null 2>&1
    case ":$PATH:" in *":./bin:"*|*":./node_modules/.bin:"*) echo present ;; *) echo absent ;; esac
  ' _ "$fixture" "$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "absent" ]
}
