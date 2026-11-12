#!/usr/bin/env bats
# tests/zshenv_git_config.bats — GIT_CONFIG_GLOBAL policy in .zshenv.
#
# A fixture ZDOTDIR (only .zshenv + env.sh) keeps the host's .zshenv.local and
# .zdots.local out of the result.

setup() {
  load "setup.bash"
  setup_environment
  FIXTURE="$BATS_TEST_TMPDIR/zshenv"
  mkdir -p "$FIXTURE"
  cp "$REPO_ROOT/.zshenv" "$REPO_ROOT/env.sh" "$FIXTURE/"
}

@test ".zshenv: points git at the XDG config by default" {
  run env -u GIT_CONFIG_GLOBAL -u ZDOTS_GIT_CONFIG_GLOBAL ZDOTDIR="$FIXTURE" zsh -df -c '
    source "$ZDOTDIR/.zshenv" >/dev/null 2>&1
    print -r -- "${GIT_CONFIG_GLOBAL-unset}"'
  [ "$status" -eq 0 ]
  [[ "${lines[${#lines[@]}-1]}" == */git/config ]]
}

@test ".zshenv: ZDOTS_GIT_CONFIG_GLOBAL=0 keeps ~/.gitconfig in play" {
  run env -u GIT_CONFIG_GLOBAL ZDOTS_GIT_CONFIG_GLOBAL=0 ZDOTDIR="$FIXTURE" zsh -df -c '
    source "$ZDOTDIR/.zshenv" >/dev/null 2>&1
    print -r -- "${GIT_CONFIG_GLOBAL-unset}"'
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" == "unset" ]
}
