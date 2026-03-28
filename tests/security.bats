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
