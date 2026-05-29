#!/usr/bin/env bats
# tests/phi_boundary.bats — PHI safety controls: scrubber, AI boundary, audit log, history hook

setup() {
  load "setup.bash"
  setup_environment
}

_log_show_phi_boundary() {
  /usr/bin/log show \
    --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"' \
    --last 1m --info 2>/dev/null
}

_wait_for_unified_log_marker() {
  local marker="$1"
  local output=""
  for _ in 1 2 3 4 5; do
    output="$(_log_show_phi_boundary)"
    if [[ "$output" == *"$marker"* ]]; then
      printf "%s\n" "$output"
      return 0
    fi
    sleep 1
  done
  return 1
}

# ---------------------------------------------------------------------------
# PHI scrubber
# ---------------------------------------------------------------------------

@test "phi_scrubber: redacts SSN pattern" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf '123-45-6789' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "phi_scrubber: redacts MRN label" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf 'patient MRN: 00123456' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" != *"00123456"* ]]
}

@test "phi_scrubber: redacts DOB label" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf 'DOB: 01/15/1980' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" != *"01/15/1980"* ]]
}

@test "phi_scrubber: connection string — fails hard (suppress-flagged)" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf 'postgresql://user:secret@db.internal/mydb' | phi_scrub"
  [ "$status" -ne 0 ]
  [[ "$output" != *"secret"* ]]
  [[ "$output" == *"suppress-flagged"* ]]
}

@test "phi_scrubber: clean input passes through unchanged" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf 'SELECT count(*) FROM users' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "SELECT count(*) FROM users" ]]
}

@test "phi_scrubber: redacts multiple patterns in one pass" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf 'SSN 123-45-6789 MRN: 99 DOB: 01/01/2000' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "phi_scrubber: redacts cli_credentials --password flag" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'psql --password secretval host' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"secretval"* ]]
}

@test "phi_scrubber: redacts cli_credentials -p flag" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'mysql -p mypassword mydb' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"mypassword"* ]]
}

@test "phi_scrubber: redacts cli_credentials --api-key flag" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'curl https://api.example.com --api-key token123abc' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"token123abc"* ]]
}

# ---------------------------------------------------------------------------
# AI boundary — zdots_ai_gate
# ---------------------------------------------------------------------------

@test "ai_boundary: ZDOTS_AI_MODE=none exits 2" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=none zdots_ai_gate test-tool"
  [ "$status" -eq 2 ]
  [[ "$output" == *"AI unavailable"* ]]
}

@test "ai_boundary: ZDOTS_AI_MODE=local does not exit" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_ai_gate test-tool && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: ZDOTS_AI_MODE=cloud does not exit" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=cloud zdots_ai_gate test-tool && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ---------------------------------------------------------------------------
# AI boundary — zdots_assert_local_endpoint
# ---------------------------------------------------------------------------

@test "ai_boundary: loopback 127.0.0.1 passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://127.0.0.1:11500 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: RFC-1918 10.x passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://10.0.1.50:11500 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: RFC-1918 192.168.x passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://192.168.1.100:11434 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: RFC-1918 172.16-31.x passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://172.20.0.1:11500 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: non-RFC-1918 endpoint exits 1 in local mode" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://api.openai.com"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SECURITY"* ]]
}

@test "ai_boundary: cloud mode bypasses locality check" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=cloud zdots_assert_local_endpoint http://api.openai.com && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: none mode bypasses locality check" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=none zdots_assert_local_endpoint http://api.openai.com && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ---------------------------------------------------------------------------
# Audit log — zdots_audit_log
# ---------------------------------------------------------------------------

@test "audit_log: emits to Unified Logging without error (darwin)" {
  run bash -c "source $ZDOTDIR/lib/audit_log.bash && zdots_audit_log test_event detail=bats_run"
  [ "$status" -eq 0 ]
}

@test "audit_log: no-ops cleanly on non-darwin" {
  # Simulate non-darwin by overriding uname
  run bash -c "
    uname() { echo Linux; }
    export -f uname
    source $ZDOTDIR/lib/audit_log.bash
    zdots_audit_log test_event detail=linux_noop
    echo ok
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "audit_log: boundary_violation event lands in log store" {
  local marker="bats_$$_$(date +%s)"
  run bash -c "source $ZDOTDIR/lib/audit_log.bash && zdots_audit_log boundary_violation test_marker=$marker"
  [ "$status" -eq 0 ]
  run _wait_for_unified_log_marker "$marker"
  if [ "$status" -ne 0 ]; then skip "Unified Logging not observable in this environment"; fi
  [[ "$output" == *"boundary_violation"* ]]
  [[ "$output" == *"$marker"* ]]
}

@test "audit_log: fault events appear as Fault type in log store" {
  local marker="fault_$$_$(date +%s)"
  bash -c "source $ZDOTDIR/lib/audit_log.bash && zdots_audit_log endpoint_assertion_fail test_marker=$marker"
  run _wait_for_unified_log_marker "$marker"
  if [ "$status" -ne 0 ]; then skip "Unified Logging not observable in this environment"; fi
  # Fault entries contain "Fault" in the log show output
  local fault_line
  fault_line=$(echo "$output" | grep "$marker")
  [[ "$fault_line" == *"Fault"* ]]
}

@test "audit_log: pass events appear as Info type in log store" {
  local marker="pass_$$_$(date +%s)"
  bash -c "source $ZDOTDIR/lib/audit_log.bash && zdots_audit_log endpoint_assertion_pass test_marker=$marker"
  run _wait_for_unified_log_marker "$marker"
  if [ "$status" -ne 0 ]; then skip "Unified Logging not observable in this environment"; fi
  local info_line
  info_line=$(echo "$output" | grep "$marker")
  [[ "$info_line" == *"Info"* ]]
}

# ---------------------------------------------------------------------------
# Shell hook metrics
# ---------------------------------------------------------------------------

@test "shell_hook_metrics: records slow hook overhead in SQLite" {
  local state_dir
  state_dir=$(mktemp -d)

  run zsh -c '
    XDG_STATE_HOME="'"$state_dir"'"
    ZDOTDIR="'"$ZDOTDIR"'"
    source "$ZDOTDIR/lib/shell_hook_metrics.bash"
    shell_hook_metrics_record "phi-history" "clean" 18 1 1700000000000
    result=""
    for _ in 1 2 3 4 5; do
      result=$(sqlite3 "$XDG_STATE_HOME/zdots/history.sqlite3" "SELECT hook, status, elapsed_ms, threshold_ms FROM shell_hook_metrics;" 2>/dev/null || true)
      [[ -n "$result" ]] && break
      sleep 0.2
    done
    printf "%s\n" "$result"
    rm -rf "$XDG_STATE_HOME"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"phi-history|clean|18|1"* ]]
}

# ---------------------------------------------------------------------------
# PHI history hook
# ---------------------------------------------------------------------------

@test "phi_history: SSN is redacted in history" {
  run zsh -c '
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    ZDOTS_HISTORY_REDACT=1
    HISTFILE=$(mktemp)
    zshaddhistory "cmd with 123-45-6789 in it"
    fc -l 1 2>/dev/null
    rm -f "$HISTFILE"
  '
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "phi_history: connection string is suppressed entirely" {
  run zsh -c '
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    ZDOTS_HISTORY_REDACT=1
    HISTFILE=$(mktemp)
    result=$(zshaddhistory "psql postgresql://user:pass@host/db"; echo $?)
    # hook returns 1 (suppress) for connection strings
    echo "return:$result"
    rm -f "$HISTFILE"
  '
  [[ "$output" == *"return:1"* ]]
}

@test "phi_history: clean command is allowed through" {
  run zsh -c '
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    ZDOTS_HISTORY_REDACT=1
    zshaddhistory "git status"
    echo "return:$?"
  '
  [[ "$output" == *"return:0"* ]]
}

@test "phi_history: hook skipped when ZDOTS_HISTORY_REDACT=0" {
  run zsh -c '
    ZDOTS_HISTORY_REDACT=0
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    # If skipped, zshaddhistory function should not exist
    typeset -f zshaddhistory > /dev/null 2>&1 && echo "defined" || echo "skipped"
  '
  [[ "$output" == *"skipped"* ]]
}

@test "phi_history: suppressed command emits audit event" {
  run zsh -c '
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    # Stub audit_log after sourcing (55-phi-history sources audit_log.bash which defines it)
    _audit_tmp=$(mktemp)
    zdots_audit_log() { printf "%s\n" "$1" >> "$_audit_tmp"; }
    ZDOTS_HISTORY_REDACT=1
    zshaddhistory "psql postgresql://user:pass@host/db"
    cat "$_audit_tmp"; rm -f "$_audit_tmp"
  '
  [[ "$output" == *"history_suppressed"* ]]
}

@test "phi_history: redacted command emits audit event" {
  run zsh -c '
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    _audit_tmp=$(mktemp)
    zdots_audit_log() { printf "%s\n" "$1" >> "$_audit_tmp"; }
    ZDOTS_HISTORY_REDACT=1
    HISTFILE=$(mktemp)
    zshaddhistory "cmd with SSN 123-45-6789 here"
    cat "$_audit_tmp"; rm -f "$_audit_tmp"
  '
  [[ "$output" == *"history_redacted"* ]]
}

# ---------------------------------------------------------------------------
# ZDOTS_LAST_COMMAND truncation
# ---------------------------------------------------------------------------

@test "observability: ZDOTS_LAST_COMMAND capped at 512 bytes" {
  # zdots_trace_init guard in 05-observability.zsh requires the function to exist
  # before the file is sourced; stub it and zdots_trace_log to avoid real tracing.
  run zsh -c '
    PATH="/usr/bin:/bin"
    autoload -Uz add-zsh-hook
    function zdots_trace_init { :; }
    function zdots_trace_log  { :; }
    source '"$ZDOTDIR"'/conf.d/05-observability.zsh
    long=$(printf "%0.s-" {1..600})
    _zdots_trace_preexec "$long"
    printf "%d\n" "${#ZDOTS_LAST_COMMAND}"
  '
  [ "$status" -eq 0 ]
  [ "$output" -le 512 ]
}

# ---------------------------------------------------------------------------
# PHI Pattern Registry — etc/phi-patterns.yaml + lib/phi_scrubber.bash
# ---------------------------------------------------------------------------

@test "phi_registry: yq required — fails hard when absent" {
  # PATH keeps bash but excludes Homebrew (where yq lives)
  run bash -c "
    PATH='/usr/bin:/bin' \
    ZDOTDIR='$ZDOTDIR' \
    bash -c 'source $ZDOTDIR/lib/phi_scrubber.bash && phi_scrub <<< test 2>&1; exit \$?'
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"yq"* ]]
}

@test "phi_registry: patterns file missing — fails hard" {
  run bash -c "
    ZDOTDIR='$BATS_TEST_TMPDIR' \
    bash -c 'source $ZDOTDIR/lib/phi_scrubber.bash && printf test | phi_scrub'
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"pattern registry not found"* ]]
}

@test "phi_registry: compiles SSN pattern from YAML" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf '123-45-6789' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "phi_registry: compiles MRN pattern from YAML" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'MRN: 00123456' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
}

@test "phi_registry: compiles DOB pattern from YAML" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'DOB: 01/15/1980' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
}

@test "phi_registry: conn_string is suppress-flagged — phi_scrub fails hard" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'postgresql://user:secret@db.internal/mydb' | phi_scrub"
  [ "$status" -ne 0 ]
  [[ "$output" != *"secret"* ]]
}

@test "phi_registry: phi_should_suppress true for conn_string" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && phi_should_suppress 'psql postgresql://user:pass@host/db'"
  [ "$status" -eq 0 ]
}

@test "phi_registry: phi_should_suppress false for SSN (redact, not suppress)" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && phi_should_suppress '123-45-6789' && echo suppressed || echo redact"
  [[ "$output" == *"redact"* ]]
}

@test "phi_registry: phi_should_suppress false for clean input" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && phi_should_suppress 'git status' && echo suppressed || echo clean"
  [[ "$output" == *"clean"* ]]
}

@test "phi_registry: phi_should_suppress true for mysql conn string" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && phi_should_suppress 'mysql://user:pass@host/db'"
  [ "$status" -eq 0 ]
}

@test "phi_registry: phi_should_suppress true for redis conn string" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && phi_should_suppress 'redis://user:pass@host:6379/0'"
  [ "$status" -eq 0 ]
}

@test "phi_registry: inline_credentials pattern redacted" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'export api_key=abc123secret' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"abc123secret"* ]]
}

@test "phi_registry: phi_scrubber_init eager compilation" {
  run bash -c "
    ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/phi_scrubber.bash
    phi_scrubber_init
    echo \"sed_args=\${#_PHI_SED_ARGS[@]}\"
    echo \"suppress_pattern=\${#_PHI_SUPPRESS_PATTERN}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"sed_args="[1-9]* ]]
  [[ "$output" == *"suppress_pattern="[1-9]* ]]
}

@test "phi_registry: cached — _PHI_SED_ARGS populated after first scrub" {
  # Use herestring (not pipe) so phi_scrub runs in current process, not a subshell
  run bash -c "
    ZDOTDIR='$ZDOTDIR'
    source $ZDOTDIR/lib/phi_scrubber.bash
    phi_scrub <<< 'test input' > /dev/null
    echo \"\${#_PHI_SED_ARGS[@]}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "phi_registry: three redact patterns active in one pass" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'SSN 123-45-6789 MRN: 99 DOB: 01/01/2000' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
}

@test "phi_registry: cross-layer — history hook uses registry suppress pattern" {
  run zsh -c '
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    ZDOTS_HISTORY_REDACT=1
    zshaddhistory "psql postgresql://user:pass@host/db"
    echo "return:$?"
  '
  [[ "$output" == *"return:1"* ]]
}

@test "phi_registry: cross-layer — history hook uses registry credential pattern" {
  run zsh -c '
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    ZDOTS_HISTORY_REDACT=1
    HISTFILE=$(mktemp)
    zshaddhistory "curl https://api.example.com --token abc123"
    fc -l 1 2>/dev/null
    rm -f "$HISTFILE"
  '
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"abc123"* ]]
}

@test "phi_registry: cross-layer — history hook redacts cli_credentials" {
  run zsh -c '
    ZDOTDIR="'"$ZDOTDIR"'"
    source '"$ZDOTDIR"'/conf.d/55-phi-history.zsh
    ZDOTS_HISTORY_REDACT=1
    HISTFILE=$(mktemp)
    zshaddhistory "psql --password secretval mydb"
    fc -l 1 2>/dev/null
    rm -f "$HISTFILE"
  '
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"secretval"* ]]
}

# ---------------------------------------------------------------------------
# Message Hygiene Pipeline
# ---------------------------------------------------------------------------

@test "message_hygiene: clean input passes through" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/message_hygiene.bash && printf 'SELECT count(*) FROM users' | zdots_message_hygiene"
  [ "$status" -eq 0 ]
  [[ "$output" == "SELECT count(*) FROM users" ]]
}

@test "message_hygiene: redacts SSN in pipeline" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/message_hygiene.bash && printf 'patient SSN 123-45-6789 admitted' | zdots_message_hygiene"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "message_hygiene: fails hard on conn_string" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/message_hygiene.bash && printf 'postgresql://user:secret@db.internal/mydb' | zdots_message_hygiene 2>&1; printf 'exit:%d\n' \$?"
  [[ "$output" == *"exit:1"* ]]
  [[ "$output" != *"secret"* ]]
}

@test "message_hygiene: strips ANSI escapes before PHI matching" {
  # Normalization runs before phi_scrub — ANSI-wrapped credentials must still be redacted.
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/message_hygiene.bash && printf 'token=\033[1mabc123\033[0m' | zdots_message_hygiene"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"abc123"* ]]
}
