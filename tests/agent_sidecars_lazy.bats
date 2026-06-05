#!/usr/bin/env bats
# tests/agent_sidecars_lazy.bats - lazy interactive agent sidecars

setup() {
  load "setup.bash"
  setup_environment
}

make_provider_root() {
  export LAZY_ROOT="$BATS_TEST_TMPDIR/zdotdir"
  export LAZY_MARKER="$BATS_TEST_TMPDIR/provider-loads"
  mkdir -p "$LAZY_ROOT/providers/tools"
}

@test "95-ai exposes zpi without sourcing Pi provider at startup" {
  make_provider_root
  cat > "$LAZY_ROOT/providers/tools/pi.zsh" <<'ZSH'
print "pi" >> "$LAZY_MARKER"
zpi() { print "pi:$*"; }
ZSH

  run zsh -c "
    export ZDOTDIR='$LAZY_ROOT'
    export LAZY_MARKER='$LAZY_MARKER'
    source '$REPO_ROOT/conf.d/95-ai.zsh'
    [[ ! -f '$LAZY_MARKER' ]] || exit 10
    typeset -f zpi >/dev/null || exit 11
    zpi hello
    grep -q '^pi$' '$LAZY_MARKER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"pi:hello"* ]]
}

@test "95-ai exposes zaider and laid without sourcing Aider provider at startup" {
  make_provider_root
  cat > "$LAZY_ROOT/providers/tools/aider.zsh" <<'ZSH'
print "aider" >> "$LAZY_MARKER"
zaider() { print "zaider:$*"; }
laid() { print "laid:$*"; }
ZSH

  run zsh -c "
    export ZDOTDIR='$LAZY_ROOT'
    export LAZY_MARKER='$LAZY_MARKER'
    source '$REPO_ROOT/conf.d/95-ai.zsh'
    [[ ! -f '$LAZY_MARKER' ]] || exit 10
    typeset -f zaider >/dev/null || exit 11
    typeset -f laid >/dev/null || exit 12
    zaider one
    laid two
    grep -q '^aider$' '$LAZY_MARKER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"zaider:one"* ]]
  [[ "$output" == *"laid:two"* ]]
}

@test "95-ai exposes zai without sourcing the router provider at startup" {
  make_provider_root
  cat > "$LAZY_ROOT/providers/tools/router.zsh" <<'ZSH'
print "router" >> "$LAZY_MARKER"
zai() { print "zai:$*"; }
ZSH

  run zsh -c "
    export ZDOTDIR='$LAZY_ROOT'
    export LAZY_MARKER='$LAZY_MARKER'
    source '$REPO_ROOT/conf.d/95-ai.zsh'
    [[ ! -f '$LAZY_MARKER' ]] || exit 10
    typeset -f zai >/dev/null || exit 11
    zai route this
    grep -q '^router$' '$LAZY_MARKER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"zai:route this"* ]]
}
