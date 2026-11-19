#!/usr/bin/env bats
# tests/zdots_sanitize.bats — Tests for bin/zdots-sanitize

setup() {
  load "setup.bash"
  setup_environment
  TOOL="$REPO_ROOT/bin/zdots-sanitize"
  SAMPLE_DIR="$BATS_TEST_TMPDIR/sample_rails_app"
  mkdir -p "$SAMPLE_DIR/config/initializers" "$SAMPLE_DIR/app/models"
}

@test "zdots-sanitize --help exits 0 and prints usage" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"zdots-sanitize"* ]]
  [[ "$output" == *"scan <dir>"* ]]
  [[ "$output" == *"apply <dir>"* ]]
}

@test "scan emits anonymized report with zero raw secrets and catches Rails patterns" {
  local fake_aws="AKIA""IOSFODNN7EXAMPLE"
  local fake_skb="9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c"
  local fake_db_pass="Sup3rS3cretDbPass!"
  local fake_url_pass="UrlPass987654"
  local fake_master="0123456789abcdef0123456789abcdef"

  printf '%s\n' "$fake_master" > "$SAMPLE_DIR/config/master.key"
  printf 'API_SECRET=TopSecretEnvValue123\n' > "$SAMPLE_DIR/.env"
  printf 'API_SECRET=changeme\n' > "$SAMPLE_DIR/.env.example"

  cat > "$SAMPLE_DIR/config/database.yml" <<EOF
production:
  adapter: postgresql
  password: $fake_db_pass
  url: postgres://appuser:$fake_url_pass@db.example.com:5432/prod
  safe_password: <%= ENV["DB_PASSWORD"] %>
EOF

  cat > "$SAMPLE_DIR/config/initializers/secrets.rb" <<EOF
Rails.application.config.secret_key_base = "$fake_skb"
AWS_KEY = "$fake_aws"
EOF

  local report="$BATS_TEST_TMPDIR/report.json"
  run "$TOOL" scan "$SAMPLE_DIR" -o "$report" --summary
  [ "$status" -eq 0 ]
  [ -f "$report" ]

  # Zero-leakage check: none of the raw secrets may appear in the report
  ! grep -q "$fake_aws" "$report"
  ! grep -q "$fake_skb" "$report"
  ! grep -q "$fake_db_pass" "$report"
  ! grep -q "$fake_url_pass" "$report"
  ! grep -q "$fake_master" "$report"
  ! grep -q "TopSecretEnvValue123" "$report"

  # Expected rules detected; .env.example and ENV[...] ignored
  grep -q '"rails_master_key_file"' "$report"
  grep -q '"env_file"' "$report"
  grep -q '"rails_secret_key_base"' "$report"
  grep -q '"aws_access_key"' "$report"
  grep -q '"url_credentials"' "$report"
  grep -q '"config_kv_secret"' "$report"
  ! grep -q '.env.example' "$report"
  ! grep -q 'safe_password' "$report"

  # Markdown format also works and leaks nothing
  run "$TOOL" scan "$SAMPLE_DIR" --format md
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Sanitization Report (Anonymized)"* ]]
  ! [[ "$output" == *"$fake_aws"* ]]
  ! [[ "$output" == *"$fake_db_pass"* ]]
}

@test "apply --dry-run does not mutate files, and apply with --backup-dir surgically redacts" {
  local fake_aws="AKIA""IOSFODNN7EXAMPLE"
  local fake_skb="9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c"
  local fake_url_pass="UrlPass987654"

  printf '0123456789abcdef0123456789abcdef\n' > "$SAMPLE_DIR/config/master.key"
  cat > "$SAMPLE_DIR/config/initializers/secrets.rb" <<EOF
Rails.application.config.secret_key_base = "$fake_skb"
AWS_KEY = "$fake_aws"
DB_URL = "postgres://appuser:$fake_url_pass@db.example.com:5432/prod"
EOF

  local report="$BATS_TEST_TMPDIR/report.json"
  "$TOOL" scan "$SAMPLE_DIR" -o "$report"

  # Dry-run leaves everything intact
  run "$TOOL" apply "$SAMPLE_DIR" "$report" --dry-run
  [ "$status" -eq 0 ]
  [ -f "$SAMPLE_DIR/config/master.key" ]
  grep -q "$fake_aws" "$SAMPLE_DIR/config/initializers/secrets.rb"

  # Real apply with backup
  local backup="$BATS_TEST_TMPDIR/backup"
  run "$TOOL" apply "$SAMPLE_DIR" "$report" --backup-dir "$backup"
  [ "$status" -eq 0 ]

  # master.key deleted, but backed up
  [ ! -f "$SAMPLE_DIR/config/master.key" ]
  [ -f "$backup/config/master.key" ]

  # Secrets replaced surgically, surrounding code preserved
  ! grep -q "$fake_aws" "$SAMPLE_DIR/config/initializers/secrets.rb"
  ! grep -q "$fake_skb" "$SAMPLE_DIR/config/initializers/secrets.rb"
  ! grep -q "$fake_url_pass" "$SAMPLE_DIR/config/initializers/secrets.rb"
  grep -q 'postgres://appuser:REDACTED_URL_CREDENTIALS_' "$SAMPLE_DIR/config/initializers/secrets.rb"
  grep -q 'Rails.application.config.secret_key_base = "REDACTED_' "$SAMPLE_DIR/config/initializers/secrets.rb"

  # Backup still has original
  grep -q "$fake_aws" "$backup/config/initializers/secrets.rb"
}
