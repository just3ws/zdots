#!/usr/bin/env bats
# tests/security.bats — Verify security hardening of the shell control plane

setup() {
  load "setup.bash"
  setup_environment
}

@test "Security: State directory has restricted permissions (700)" {
  local state_zsh="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
  # Trigger creation if not exists
  run zsh -i -c "true"
  
  [ -d "$state_zsh" ]
  local perms=$(stat -f "%Lp" "$state_zsh" 2>/dev/null || stat -c "%a" "$state_zsh")
  [ "$perms" == "700" ]
}

@test "Security: Trace file has restricted permissions (600)" {
  local trace_file="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/traces.jsonl"
  run zsh -i -c "true"
  
  [ -f "$trace_file" ]
  local perms=$(stat -f "%Lp" "$trace_file" 2>/dev/null || stat -c "%a" "$trace_file")
  [ "$perms" == "600" ]
}

@test "Security: Sensitive command-line arguments are redacted" {
  # We test the redaction helper directly by sourcing env.sh
  run zsh -c ". $ZDOTDIR/env.sh && zdots_trace_redact 'mysql --password secret_pass -e select'"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [[ "$val" == *"--password [REDACTED]"* ]]
  [[ "$val" != *"secret_pass"* ]]
}

@test "Security: umask is set to 077" {
  run zsh -i -c "umask"
  echo "Output: $output"
  local val=$(echo "$output" | tail -n 1)
  # Handle both 0077 and 77 formats
  [[ "$val" == *"77"* ]]
}

@test "Security: secret-scan detects inline hex key assignment (regression: ZDOTS_DB_ENCRYPTION_KEY leak)" {
  # A 64-char hex value assigned inline to a *_KEY var must be flagged.
  # This pattern is what leaked in .claude/settings.local.json commit 6996114.
  local fixture
  fixture="$(mktemp)"
  echo 'ZDOTS_DB_ENCRYPTION_KEY="47343e0d92e06a3a72c5baf0dc62decd49461f37b7a3c09019142891046d5374"' > "$fixture"

  run rg --no-heading -n \
    '[A-Z_]+(?:KEY|SECRET|PASSWORD|TOKEN)\s*=\s*["'"'"']?[0-9a-fA-F]{32,}["'"'"']?' \
    "$fixture"

  rm -f "$fixture"
  echo "Output: $output"
  [ "$status" -eq 0 ]
}

@test "Security: .claude/settings.local.json is not tracked by git" {
  # This file accumulates session permissions and may contain inline secrets.
  # It must remain gitignored and never enter the commit history again.
  run git -C "$ZDOTDIR" ls-files --error-unmatch .claude/settings.local.json
  [ "$status" -ne 0 ]
}

@test "Security: secret-scan passes on clean working tree" {
  run "$ZDOTDIR/bin/secret-scan"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}
