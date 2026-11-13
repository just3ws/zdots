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

# Host and port are settings (ZDOTS_GEMSTASH_HOST / ZDOTS_GEMSTASH_PORT),
# loopback only, defaulting to 127.0.0.1:9292.
@test "gemstash-ctl init binds 127.0.0.1:9292 by default" {
  run env -u ZDOTS_GEMSTASH_HOST -u ZDOTS_GEMSTASH_PORT HOME="$TMP" "$CTL" init
  [ "$status" -eq 0 ]
  grep -qx ':bind: tcp://127.0.0.1:9292' "$TMP/.gemstash/config.yml"
}

@test "gemstash-ctl init uses the configured loopback host and port" {
  run env HOME="$TMP" ZDOTS_GEMSTASH_HOST=localhost ZDOTS_GEMSTASH_PORT=44292 "$CTL" init
  [ "$status" -eq 0 ]
  grep -qx ':bind: tcp://localhost:44292' "$TMP/.gemstash/config.yml"
}

@test "gemstash-ctl init brackets an IPv6 loopback host" {
  run env HOME="$TMP" ZDOTS_GEMSTASH_HOST=::1 ZDOTS_GEMSTASH_PORT=44292 "$CTL" init
  [ "$status" -eq 0 ]
  grep -qx ':bind: tcp://\[::1\]:44292' "$TMP/.gemstash/config.yml"
}

@test "gemstash-ctl refuses a non-loopback host" {
  run env HOME="$TMP" ZDOTS_GEMSTASH_HOST=0.0.0.0 "$CTL" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"loopback"* ]]
  [ ! -f "$TMP/.gemstash/config.yml" ]
}

@test "gemstash-ctl refuses a port outside 1-65535" {
  run env HOME="$TMP" ZDOTS_GEMSTASH_PORT=70000 "$CTL" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"port"* ]]
}

@test "gemstash-ctl status reports the configured endpoint" {
  run env HOME="$TMP" ZDOTS_GEMSTASH_PORT=44292 "$CTL" status --json
  [[ "$output" == *"127.0.0.1:44292"* ]]
}

@test "svc-registry and svc-map use the configured gemstash port" {
  run bash -c "export ZDOTS_GEMSTASH_PORT=44292; source '$REPO_ROOT/lib/svc-registry.bash'; printf '%s\n' \"\${ZDOTS_SVC_ENDPOINT[gemstash]}\""
  [ "$output" = "http://127.0.0.1:44292" ]
  ! grep -q '127.0.0.1:9292' "$REPO_ROOT/lib/svc-map.bash"
}
