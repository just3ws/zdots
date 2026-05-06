#!/usr/bin/env bats
# tests/metadata.bats — Tests for the Platform Metadata Service

setup() {
  load "setup"
  setup_environment
  source "$REPO_ROOT/lib/metadata.bash"
  
  # Create a mock config for testing overrides
  TEST_CONFIG_DIR=$(mktemp -d)
  ZDOTS_META_DIR="$TEST_CONFIG_DIR"
  
  cat > "$ZDOTS_META_DIR/ai-models.yaml" <<EOF
profiles:
  standard:
    model_file: "std.gguf"
    ctx_size: 4096
  tiny:
    model_file: "tiny.gguf"
    ctx_size: 1024

default_profile: "standard"

server:
  host: "127.0.0.1"
  port: 8080
  ctx_size: 2048
EOF
}

teardown() {
  rm -rf "$TEST_CONFIG_DIR"
}

@test "metadata: resolves default profile" {
  unset ZDOTS_AI_PROFILE
  run zdots_meta_resolve_yaml ai model_file
  [ "$status" -eq 0 ]
  [ "$output" = "std.gguf" ]
}

@test "metadata: resolves active profile override" {
  export ZDOTS_AI_PROFILE=tiny
  run zdots_meta_resolve_yaml ai model_file
  [ "$status" -eq 0 ]
  [ "$output" = "tiny.gguf" ]
}

@test "metadata: merges profile with server defaults" {
  export ZDOTS_AI_PROFILE=tiny
  run zdots_meta_resolve_yaml ai port
  [ "$status" -eq 0 ]
  [ "$output" = "8080" ]
}

@test "metadata: profile overrides server defaults" {
  export ZDOTS_AI_PROFILE=standard
  run zdots_meta_resolve_yaml ai ctx_size
  [ "$status" -eq 0 ]
  [ "$output" = "4096" ]
}

@test "metadata: dump ai returns full json" {
  export ZDOTS_AI_PROFILE=standard
  run zdots_meta_dump ai
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .model_file)" = "std.gguf" ]
  [ "$(echo "$output" | jq -r .port)" = "8080" ]
  [ "$(echo "$output" | jq -r .active_profile)" = "standard" ]
}

@test "metadata: env outputs export statements" {
  export ZDOTS_AI_PROFILE=standard
  run zdots_meta_env ai
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'export ZDOTS_AI_MODEL_FILE="std.gguf"'
  echo "$output" | grep -q 'export ZDOTS_AI_PORT="8080"'
}

@test "metadata: dump platform aggregates services" {
  # Mock other files
  echo '{"foo":"bar"}' > "$ZDOTS_META_DIR/otel-collector.yaml"
  echo '{"baz":"qux"}' > "$ZDOTS_META_DIR/docker-compose.lgtm.yaml"
  
  run zdots_meta_dump platform
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .ai.model_file)" = "std.gguf" ]
  [ "$(echo "$output" | jq -r .otel.foo)" = "bar" ]
}
