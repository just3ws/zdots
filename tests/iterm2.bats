#!/usr/bin/env bats
# tests/iterm2.bats — iTerm2 shell integration and utilities load wherever
# iTerm2 is the outer terminal, including inside tmux, and nowhere else.
# `script` gives the shell a terminal, so ZLE is on as in a real session.

setup() {
  load "setup.bash"
  setup_environment
}

# iterm_shell <env…> — print the integration flag and imgcat's path from an
# interactive shell started with the given environment.
iterm_shell() {
  env "$@" ZDOTDIR="$REPO_ROOT" script -q /dev/null zsh -i -c \
    'print -r -- "INTEG=${ITERM_SHELL_INTEGRATION_INSTALLED:-no} IMGCAT=$(whence -p imgcat || print none)"' 2>/dev/null |
    tr -d '\r' | grep -Eo 'INTEG=[A-Za-z]+ IMGCAT=[^[:cntrl:]]*' | tail -1
}

@test "iterm2: integration and utilities load inside tmux under iTerm2" {
  run iterm_shell TERM=tmux-256color TERM_PROGRAM=tmux TMUX=/tmp/fake,1,0 LC_TERMINAL=iTerm2
  [[ "$output" == "INTEG=Yes IMGCAT=/"*"/imgcat" ]]
}

@test "iterm2: integration and utilities load in iTerm2 without tmux" {
  run iterm_shell TERM=xterm-256color TERM_PROGRAM=iTerm.app LC_TERMINAL=iTerm2
  [[ "$output" == "INTEG=Yes IMGCAT=/"*"/imgcat" ]]
}

@test "iterm2: nothing loads in another terminal" {
  run iterm_shell TERM=xterm-256color TERM_PROGRAM=Apple_Terminal LC_TERMINAL= TMUX=
  [ "$output" = "INTEG=no IMGCAT=none" ]
}

@test "iterm2: vendored utilities are text scripts, never binaries" {
  run bash -c "file '$REPO_ROOT'/.iterm2/* | grep -v 'text' || true"
  [ -z "$output" ]
}
