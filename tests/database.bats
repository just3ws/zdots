#!/usr/bin/env bats
# tests/database.bats — Database architecture contract tests
#
# Validates that the database consolidation onto 'my' is correct and
# role-based access control is enforced. These tests are the tripwire:
# if an agent goes rogue and misconfigures the database layer, these fail.
#
# Tests require a running PostgreSQL with the 'my' database. They are
# skipped automatically if psql cannot connect.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_pg_up() {
  psql -q -U zdots_ro my -c "SELECT 1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Connectivity: correct database, correct users
# ---------------------------------------------------------------------------

@test "database: zdots_ro can connect to 'my'" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "SELECT current_database()"
  [ "$status" -eq 0 ]
  [[ "$output" == *"my"* ]]
}

@test "database: zdots_rw can connect to 'my'" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_rw my -c "SELECT current_database()"
  [ "$status" -eq 0 ]
  [[ "$output" == *"my"* ]]
}

@test "database: 'zdots' database does not exist" {
  # The old zdots database was dropped; it must stay gone.
  run psql -q -U zdots_ro -l
  [ "$status" -eq 0 ]
  [[ "$output" != *" zdots "* ]]
}

# ---------------------------------------------------------------------------
# Schema: required tables exist
# ---------------------------------------------------------------------------

@test "database: 'jobs' table exists" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "\d jobs"
  [ "$status" -eq 0 ]
}

@test "database: 'lessons' table exists" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "\d lessons"
  [ "$status" -eq 0 ]
}

@test "database: 'methodologies' table exists" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "\d methodologies"
  [ "$status" -eq 0 ]
}

@test "database: 'session_residue' table exists" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "\d session_residue"
  [ "$status" -eq 0 ]
}

@test "database: migration tracking table exists" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "\d zdots_schema_migrations"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Role enforcement: zdots_ro is truly read-only
# ---------------------------------------------------------------------------

@test "database: zdots_ro cannot INSERT into lessons" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c \
    "INSERT INTO lessons (content) VALUES ('test-permission-check')"
  [ "$status" -ne 0 ]
  [[ "$output" == *"permission denied"* ]]
}

@test "database: zdots_ro cannot DELETE from lessons" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "DELETE FROM lessons WHERE 1=0"
  [ "$status" -ne 0 ]
  [[ "$output" == *"permission denied"* ]]
}

@test "database: zdots_ro cannot INSERT into jobs" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c \
    "INSERT INTO jobs (type, payload) VALUES ('test', '{}'::jsonb)"
  [ "$status" -ne 0 ]
  [[ "$output" == *"permission denied"* ]]
}

@test "database: zdots_ro cannot DROP tables" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c "DROP TABLE lessons"
  [ "$status" -ne 0 ]
  [[ "$output" == *"permission denied"* || "$output" == *"must be owner"* ]]
}

# ---------------------------------------------------------------------------
# Role enforcement: zdots_rw can write through functions
# ---------------------------------------------------------------------------

@test "database: claim_next_job function exists and is callable by zdots_rw" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  # Call with worker_id and job_type — returns NULL when queue is empty, which is fine
  run psql -q -U zdots_rw my -c \
    "SELECT claim_next_job('test-worker', 'nonexistent_type')"
  [ "$status" -eq 0 ]
}

@test "database: zdots_ro cannot call claim_next_job" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run psql -q -U zdots_ro my -c \
    "SELECT claim_next_job('test-worker', 'nonexistent_type')"
  [ "$status" -ne 0 ]
  [[ "$output" == *"permission denied"* ]]
}

# ---------------------------------------------------------------------------
# Environment: ZDOTS_DATABASE_URL points to 'my', not 'zdots' or anything else
# ---------------------------------------------------------------------------

@test "env: ZDOTS_DATABASE_URL default targets the 'my' database" {
  # Unset ZDOTS_DATABASE_URL_OVERRIDE and ZDOTS_DATABASE_URL, source env, check the result
  result=$(env -u ZDOTS_DATABASE_URL \
    bash -c 'source "'"$REPO_ROOT"'/.zdots.env" 2>/dev/null; echo "$ZDOTS_DATABASE_URL"')
  # Extract the database name (last path component after @/ or last /)
  db_name="${result##*/}"
  [ "$db_name" = "my" ]
}

@test "env: ZDOTS_DATABASE_URL does not target 'zdots' database" {
  result=$(env -u ZDOTS_DATABASE_URL \
    bash -c 'source "'"$REPO_ROOT"'/.zdots.env" 2>/dev/null; echo "$ZDOTS_DATABASE_URL"')
  # Extract the database name — should be 'my', not 'zdots'
  db_name="${result##*/}"
  [ "$db_name" != "zdots" ]
}

@test "env: explicit ZDOTS_DATABASE_URL is not overridden by .zdots.env" {
  # ZDOTS_DATABASE_URL is namespaced — if the caller sets it explicitly, respect it.
  result=$(ZDOTS_DATABASE_URL="postgresql://zdots_rw@/other" \
    bash -c 'source "'"$REPO_ROOT"'/.zdots.env" 2>/dev/null; echo "$ZDOTS_DATABASE_URL"')
  [ "$result" = "postgresql://zdots_rw@/other" ]
}

@test "env: bare DATABASE_URL does not bleed into ZDOTS_DATABASE_URL" {
  # The whole point of the rename: DATABASE_URL set by an external tool must not
  # pollute ZDOTS_DATABASE_URL. These are independent variables.
  result=$(env -u ZDOTS_DATABASE_URL DATABASE_URL="postgresql://someone-else@/other" \
    bash -c 'source "'"$REPO_ROOT"'/.zdots.env" 2>/dev/null; echo "$ZDOTS_DATABASE_URL"')
  db_name="${result##*/}"
  [ "$db_name" = "my" ]
}

# ---------------------------------------------------------------------------
# zdots-ctx: CLI reports correct database
# ---------------------------------------------------------------------------

@test "zdots-ctx: status exits 0 with correct database" {
  if ! _pg_up; then skip "PostgreSQL not available"; fi
  run "$BIN/zdots-ctx" status
  [ "$status" -eq 0 ]
}

@test "zdots-ctx: --help mentions zdots_ro and zdots_rw users" {
  run "$BIN/zdots-ctx" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"zdots_ro"* ]]
  [[ "$output" == *"zdots_rw"* ]]
}

@test "zdots-ctx: --help mentions ZDOTS_MIGRATION_URL" {
  run "$BIN/zdots-ctx" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"ZDOTS_MIGRATION_URL"* ]]
}

@test "zdots-ctx: --help does not reference 'zdots' database" {
  run "$BIN/zdots-ctx" --help
  [ "$status" -eq 0 ]
  # ZDOTS_DATABASE_URL should reference 'my', not 'zdots'
  [[ "$output" != *"postgresql:///zdots"* ]]
  [[ "$output" != *"@/zdots"* ]]
}

# ---------------------------------------------------------------------------
# agent-guide: JSON output includes database section
# ---------------------------------------------------------------------------

@test "agent-guide: --json includes database section" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.database' >/dev/null
}

@test "agent-guide: --json database.name is 'my'" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.database.name')
  [ "$result" = "my" ]
}

@test "agent-guide: --json database.app_user is 'zdots_rw'" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.database.app_user')
  [ "$result" = "zdots_rw" ]
}

@test "agent-guide: --json database.readonly_user is 'zdots_ro'" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.database.readonly_user')
  [ "$result" = "zdots_ro" ]
}

@test "agent-guide: --json database.app_url points to 'my'" {
  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.database.app_url')
  # Extract the database name (last path component) — must be 'my'
  db_name="${result##*/}"
  [ "$db_name" = "my" ]
}
