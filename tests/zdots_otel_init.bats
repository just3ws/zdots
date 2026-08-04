#!/usr/bin/env bats
# tests/zdots_otel_init.bats — regression test for Zdots.init_otel (lib/zdots.rb).
#
# Z-229 wired OTel into zdots-worker via `c.use_all`, but `use_all` only installs
# instrumentations already registered in OpenTelemetry::Instrumentation.registry.
# Without requiring opentelemetry-instrumentation-all first, the registry is
# empty and use_all silently no-ops — confirmed 2026-08-03: zdots-worker
# processed 311 jobs/30d with zero spans ever reaching OpenObserve. This test
# asserts the instrumentation classes actually load, so a future edit that
# drops the require can't regress silently again.

setup() {
  load "setup.bash"
  setup_environment
}

@test "Zdots.init_otel loads instrumentation-all (registry is not empty)" {
  run ruby -e '
    require_relative "'"$REPO_ROOT"'/lib/zdots"
    Zdots.init_otel("test-check")
    raise "PG instrumentation not registered — opentelemetry/instrumentation/all not required" \
      unless defined?(OpenTelemetry::Instrumentation::PG::Instrumentation)
    raise "Net::HTTP instrumentation not registered" \
      unless defined?(OpenTelemetry::Instrumentation::Net::HTTP::Instrumentation)
    puts "ok"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
