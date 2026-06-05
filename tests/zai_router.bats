#!/usr/bin/env bats
# tests/zai_router.bats — zai engine router (ROUTER Phase 1) behaviour.
# Classifier is disabled (ZAI_NO_CLASSIFY=1) so these stay offline/deterministic.

setup() {
  load "setup.bash"
  setup_environment
}

@test "zai defaults to the local engine" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --dry-run 'hello world'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"engine=local"* ]]
}

@test "zai --aider selects the aider engine" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --dry-run --aider 'add a flag'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"engine=aider"* ]]
}

@test "zai --pi selects the pi engine" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --dry-run --pi 'explain x'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"engine=pi"* ]]
}

@test "zai --haiku refuses until Phase 3" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --haiku 'x'
  "
  [ "$status" -eq 3 ]
  [[ "$output" == *"enabled yet"* ]]
}

@test "zai --claude-code refuses until Phase 2" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --claude-code 'x'
  "
  [ "$status" -eq 3 ]
  [[ "$output" == *"enabled yet"* ]]
}

@test "zai rejects an unknown flag" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --bogus 'x'
  "
  [ "$status" -eq 2 ]
}
