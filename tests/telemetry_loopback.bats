#!/usr/bin/env bats
# tests/telemetry_loopback.bats — the telemetry services listen on loopback only.
# A Jaeger/collector component with no explicit endpoint binds every interface,
# so each listener must be named here with a 127.0.0.1 address.

setup() {
  load "setup.bash"
  setup_environment
}

@test "jaeger.yaml pins every listener (OTLP, UI, query gRPC) to 127.0.0.1" {
  run yq -r '[.receivers.otlp.protocols.grpc.endpoint, .extensions.jaeger_query.http.endpoint, .extensions.jaeger_query.grpc.endpoint] | .[]' "$REPO_ROOT/etc/jaeger.yaml"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "127.0.0.1:14317" ]
  [ "${lines[1]}" = "127.0.0.1:16686" ]
  [ "${lines[2]}" = "127.0.0.1:16685" ]
}

@test "no endpoint in jaeger.yaml or otel-collector.yaml binds a wildcard address" {
  run grep -n -E 'endpoint:[[:space:]]*"?(0\.0\.0\.0|\[::\]|:)[0-9]*' "$REPO_ROOT/etc/jaeger.yaml" "$REPO_ROOT/etc/otel-collector.yaml"
  [ "$status" -ne 0 ]
}
