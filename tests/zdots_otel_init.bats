#!/usr/bin/env bats
# tests/zdots_otel_init.bats — regression test for Zdots.init_otel (lib/zdots.rb).
#
# Guard the explicit instrumentation set used by PostgreSQL, RubyLLM/Faraday,
# and Net::HTTP embedding calls. A missing adapter would silently drop spans.

setup() {
  load "setup.bash"
  setup_environment
}

@test "Zdots.init_otel registers PG, Faraday, and Net::HTTP instrumentation" {
  run ruby -e '
    require_relative "'"$REPO_ROOT"'/lib/zdots"
    Zdots.init_otel("test-check")
    raise "PG instrumentation not registered" \
      unless defined?(OpenTelemetry::Instrumentation::PG::Instrumentation)
    raise "Net::HTTP instrumentation not registered" \
      unless defined?(OpenTelemetry::Instrumentation::Net::HTTP::Instrumentation)
    raise "Faraday instrumentation not registered" \
      unless defined?(OpenTelemetry::Instrumentation::Faraday::Instrumentation)
    puts "ok"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
