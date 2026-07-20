#!/usr/bin/env bats
# tests/gemstash.bats — contract for gemstash-ctl (service manager) and
# gemstash-metadata (gemspec analytics extractor over the on-disk cache).

setup() {
  load "setup"
  setup_environment
  CTL="$REPO_ROOT/bin/gemstash-ctl"
  META="$REPO_ROOT/bin/gemstash-metadata"
  TMP="$(mktemp -d)"
}

teardown() { rm -rf "$TMP"; }

@test "gemstash-ctl --help lists every dispatch verb" {
  run "$CTL" --help
  [ "$status" -eq 0 ]
  for verb in init install start stop restart status health logs run; do
    [[ "$output" == *"$verb"* ]] || { echo "help missing verb: $verb"; false; }
  done
}

@test "gemstash-ctl rejects an unknown command" {
  run "$CTL" bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "svc-registry resolves gemstash and registers its health probe" {
  run bash -c "source '$REPO_ROOT/lib/svc-registry.bash'; zdots_svc_resolve gemstash; declare -f zdots_probe_gemstash >/dev/null && echo PROBE_OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gemstash"* ]]
  [[ "$output" == *"PROBE_OK"* ]]
}

@test "gemstash-metadata --help is inert and prints usage" {
  run "$META" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "gemstash-metadata aborts on a missing cache dir" {
  run "$META" "$TMP/nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such dir"* ]]
}

@test "gemstash-metadata emits NDJSON for a cached gem" {
  local cache="$TMP/gem_cache/x"
  mkdir -p "$cache"
  CACHE="$cache" ruby -e '
    require "rubygems/package"
    spec = Gem::Specification.new do |s|
      s.name = "fixturegem"; s.version = "1.2.3"; s.summary = "fixture"
      s.authors = ["Tester"]; s.licenses = ["MIT"]; s.homepage = "https://example.test"
      s.required_ruby_version = ">= 2.0"
      s.add_runtime_dependency "rake", ">= 1.0"
    end
    Dir.chdir(ENV["CACHE"]) { Gem::Package.build(spec) }
  ' 2>/dev/null || skip "cannot build a fixture gem in this environment"
  run "$META" "$TMP/gem_cache"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"fixturegem"'* ]]
  [[ "$output" == *'"licenses":["MIT"]'* ]]
  [[ "$output" == *'"rake"'* ]]
}
