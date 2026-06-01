#!/usr/bin/env bats
# tests/platform_e2e.bats — End-to-end validation against the LIVE platform.
#
# Unlike the unit/contract suites (which mock launchctl/psql), this exercises the
# real running stack: zsvc-managed services, AI endpoints, the PostgreSQL Brain,
# the scram credential fence, Ruby toolchain, and the bump helper. Tests skip
# (not fail) when a prerequisite is genuinely absent, so the suite reflects
# reality on any machine.
#
# Run: bats tests/platform_e2e.bats

setup() {
  load "setup"
  setup_environment
  ZSVC="$REPO_ROOT/bin/zsvc"
  ZTASK="$REPO_ROOT/bin/ztask"
  CTX="$REPO_ROOT/bin/zdots-ctx"
  PSQL_OSUSER=( psql -X -q -A -t my )   # OS user over socket (trust, superuser)
  RW_PW="$(security find-generic-password -s zdots -a ZDOTS_RW_PASSWORD -w 2>/dev/null || true)"
}

_have() { command -v "$1" >/dev/null 2>&1; }

# ── zsvc: the full service control plane ────────────────────────────────────

@test "zsvc list reports all seven platform services" {
  run "$ZSVC" list
  [ "$status" -eq 0 ]
  for svc in llama-server llama-embed otel-collector colima nginx postgresql@18 redis; do
    [[ "$output" == *"$svc"* ]] || { echo "missing service in list: $svc"; false; }
  done
}

@test "zsvc list shows core services running" {
  run "$ZSVC" list
  [ "$status" -eq 0 ]
  for svc in llama-server postgresql@18 redis nginx; do
    echo "$output" | grep -E "^${svc}[[:space:]]+running" || {
      echo "service not running: $svc"; false; }
  done
}

@test "zsvc help lists nginx, postgres, redis (discoverable)" {
  run "$ZSVC" --help
  [[ "$output" == *nginx* && "$output" == *postgres* && "$output" == *redis* ]]
}

@test "zsvc status postgres probes liveness (pg_isready)" {
  run "$ZSVC" status postgres
  [ "$status" -eq 0 ]
  [[ "$output" == *"accepting connections"* ]]
}

@test "zsvc status redis probes liveness (PONG)" {
  run "$ZSVC" status redis
  [ "$status" -eq 0 ]
  [[ "$output" == *PONG* ]]
}

@test "zsvc aliases resolve (db -> postgres, cache -> redis)" {
  run "$ZSVC" status db
  [[ "$output" == *postgresql@18* ]]
  run "$ZSVC" status cache
  [[ "$output" == *redis* ]]
}

@test "zsvc logs all reports central log sources" {
  run "$ZSVC" logs all --paths
  [ "$status" -eq 0 ]
  for svc in llama-server llama-embed otel-collector nginx postgresql@18 redis; do
    [[ "$output" == *"$svc"* ]] || { echo "missing log source: $svc"; false; }
  done
}

@test "zsvc logs all --json exposes log sources for agents" {
  run "$ZSVC" logs all --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .sources
    and ([.sources[].name] | index("llama"))
    and ([.sources[].name] | index("otel"))
    and ([.sources[].name] | index("postgres"))
  ' >/dev/null
}

@test "zsvc health reports services and local URLs" {
  run "$ZSVC" health
  [[ "$output" == *llama-server* ]]
  [[ "$output" == *postgresql@18* ]]
  [[ "$output" == *redis* ]]
  [[ "$output" == *llama.local* ]]
  [[ "$output" == *my.local* ]]
}

@test "zsvc health --json exposes service and local URL state for agents" {
  run "$ZSVC" health --json
  printf '%s\n' "$output" | jq -e '
    (.healthy | type == "boolean")
    and ([.services[].name] | index("nginx"))
    and ([.services[].name] | index("redis"))
    and ([.local_urls[].name] | index("llama.local"))
    and ([.local_urls[].name] | index("my.local"))
  ' >/dev/null
}

@test "ztask health proves task orchestration dependencies" {
  run "$ZTASK" health --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .healthy == true and
    .platform_ready == true and
    .brain_ready == true and
    .hydration_ready == true
  ' >/dev/null
}

# ── AI inference + embeddings + telemetry ───────────────────────────────────

@test "llama-server answers /health on :11500" {
  curl -sf --max-time 6 http://127.0.0.1:11500/health >/dev/null \
    || skip "llama-server not responding on :11500"
}

@test "llama-embed answers /health on :11501" {
  curl -sf --max-time 6 http://127.0.0.1:11501/health >/dev/null \
    || skip "llama-embed not responding on :11501"
}

@test "otel collector OTLP/HTTP listening on :4318" {
  # GET / on the OTLP receiver returns non-000 (405/404) when up.
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:4318/ 2>/dev/null || echo 000)
  [ "$code" != "000" ] || skip "otel :4318 not listening"
}

# ── PostgreSQL Brain (zdots-ctx + my) ───────────────────────────────────────

@test "postgres accepts connections (pg_isready)" {
  _have pg_isready || skip "pg_isready not installed"
  run pg_isready -q
  [ "$status" -eq 0 ]
}

@test "zdots-ctx status connects to the Brain (scram + Keychain injection)" {
  run "$CTX" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"connected to database: my"* ]]
}

@test "Brain migrations are up to date" {
  run "$CTX" migrate
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* || "$output" == *"applying"* ]]
}

@test "Brain holds the captured methodologies and lessons" {
  run "${PSQL_OSUSER[@]}" -c "select count(*) from methodologies;"
  [ "$status" -eq 0 ]
  [ "$output" -ge 32 ]
  run "${PSQL_OSUSER[@]}" -c "select count(*) from lessons;"
  [ "$output" -ge 1 ]
}

@test "captured best-practice methodologies are present by slug" {
  run "${PSQL_OSUSER[@]}" -c \
    "select count(*) from methodologies where slug in ('zsh-no-reserved-vars','ruby-declare-runtime-gems','tools-zsvc-service-control','docs-gap-register');"
  [ "$output" -eq 4 ]
}

# ── Credential fence (scram-sha-256 at the zdots_rw boundary) ───────────────

@test "passwordless connection as zdots_rw is REJECTED (fence is real)" {
  # -w: never prompt; empty PGPASSWORD so it cannot pick one up.
  run env PGPASSWORD= psql -w -X -tAc "select 1" "postgresql://zdots_rw@127.0.0.1/my"
  [ "$status" -ne 0 ]
  [[ "$output" == *"password"* || "$output" == *"authentication"* ]]
}

@test "zdots_rw WITH the Keychain key authenticates" {
  [ -n "$RW_PW" ] || skip "no ZDOTS_RW_PASSWORD in Keychain"
  run psql -X -tAc "select current_user" "postgresql://zdots_rw:${RW_PW}@127.0.0.1/my"
  [ "$status" -eq 0 ]
  [[ "$output" == *zdots_rw* ]]
}

# ── Redis (analytics buffer) ────────────────────────────────────────────────

@test "redis answers PING" {
  _have redis-cli || skip "redis-cli not installed"
  run redis-cli ping
  [[ "$output" == "PONG" ]]
}

# ── nginx local-URL routing ─────────────────────────────────────────────────

@test "nginx is listening on :80" {
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/ 2>/dev/null || echo 000)
  [ "$code" != "000" ]
}

@test "nginx upstreams point at the live backend ports (11500/11501)" {
  conf="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/etc/nginx/servers/zdots.conf"
  [ -f "$conf" ] || skip "nginx zdots.conf not found"
  grep -q "127.0.0.1:11500" "$conf"
  grep -q "127.0.0.1:11501" "$conf"
  ! grep -qE "127.0.0.1:(8080|8090)" "$conf"
}

# ── Ruby toolchain ──────────────────────────────────────────────────────────

@test "active Ruby is latest stable (4.0.5)" {
  _have mise || skip "mise not installed"
  run mise current ruby
  [[ "$output" == 4.0.5* ]]
}

@test "Brain runtime gems load under the active Ruby" {
  _have mise || skip "mise not installed"
  run mise exec ruby@4.0.5 -- ruby -e 'require "sqlite3"; require "pg"; require "sequel"; puts "ok"'
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]]
}

@test "zdots-ruby-bump reports the pin is already latest" {
  run "$REPO_ROOT/bin/zdots-ruby-bump" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at latest"* ]]
}
