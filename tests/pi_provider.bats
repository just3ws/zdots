#!/usr/bin/env bats

setup() {
  load "setup.bash"
  setup_environment
  ROOT="$REPO_ROOT"
}

@test "zpi --or refuses Anthropic model IDs before loading cloud credentials" {
  for model in anthropic/other openrouter/anthropic/claude-3-7-sonnet; do
    run zsh -fc "
      export ZDOTDIR='$ROOT'
      source '$ROOT/providers/tools/pi.zsh'
      zdots_pi_init() { print 'cloud init was called'; }
      ZDOTS_OR_MODEL='$model' zpi --or
    "
    [ "$status" -eq 2 ]
    [[ "$output" == *"Anthropic models are disabled"* ]]
    [[ "$output" != *"cloud init was called"* ]]
  done
}

@test "zpi --or requires an explicit model" {
  run zsh -fc "
    export ZDOTDIR='$ROOT'
    source '$ROOT/providers/tools/pi.zsh'
    zdots_pi_init() { print 'cloud init was called'; }
    unset ZDOTS_OR_MODEL
    zpi --or
  "
  [ "$status" -eq 2 ]
  [[ "$output" == *"set ZDOTS_OR_MODEL explicitly"* ]]
  [[ "$output" != *"cloud init was called"* ]]
}
