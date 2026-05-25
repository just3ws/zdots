#!/usr/bin/env bats
# tests/phi_boundary.bats — PHI safety controls: scrubber, AI boundary, audit log, history hook

setup() {
  load "setup.bash"
  setup_environment
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

@test "phi_scrubber: redacts DB connection string" {
  run bash -c "source $ZDOTDIR/lib/phi_scrubber.bash && printf 'postgresql://user:secret@db.internal/mydb' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-CONN]"* ]]
  [[ "$output" != *"secret"* ]]
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
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://127.0.0.1:8080 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: RFC-1918 10.x passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://10.0.1.50:8080 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: RFC-1918 192.168.x passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://192.168.1.100:11434 && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ai_boundary: RFC-1918 172.16-31.x passes" {
  run bash -c "source $ZDOTDIR/lib/ai_boundary.bash && ZDOTS_AI_MODE=local zdots_assert_local_endpoint http://172.20.0.1:8080 && echo ok"
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
  sleep 1
  run /usr/bin/log show \
    --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"' \
    --last 1m --info
  [[ "$output" == *"boundary_violation"* ]]
  [[ "$output" == *"$marker"* ]]
}

@test "audit_log: fault events appear as Fault type in log store" {
  local marker="fault_$$_$(date +%s)"
  bash -c "source $ZDOTDIR/lib/audit_log.bash && zdots_audit_log endpoint_assertion_fail test_marker=$marker"
  sleep 1
  run /usr/bin/log show \
    --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"' \
    --last 1m --info
  # Fault entries contain "Fault" in the log show output
  local fault_line
  fault_line=$(echo "$output" | grep "$marker")
  [[ "$fault_line" == *"Fault"* ]]
}

@test "audit_log: pass events appear as Info type in log store" {
  local marker="pass_$$_$(date +%s)"
  bash -c "source $ZDOTDIR/lib/audit_log.bash && zdots_audit_log endpoint_assertion_pass test_marker=$marker"
  sleep 1
  run /usr/bin/log show \
    --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"' \
    --last 1m --info
  local info_line
  info_line=$(echo "$output" | grep "$marker")
  [[ "$info_line" == *"Info"* ]]
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

# ---------------------------------------------------------------------------
# ZDOTS_LAST_COMMAND truncation
# ---------------------------------------------------------------------------

@test "observability: ZDOTS_LAST_COMMAND capped at 512 bytes" {
  run zsh -i -c '
    long=$(printf "%0.s-" {1..600})
    _zdots_trace_preexec "$long"
    echo "${#ZDOTS_LAST_COMMAND}"
  ' 2>/dev/null
  local len
  len=$(echo "$output" | grep -Eo '^[0-9]+$' | tail -1)
  [ "$len" -le 512 ]
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

@test "phi_registry: compiles conn_string pattern from YAML" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'postgresql://user:secret@db.internal/mydb' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-CONN]"* ]]
  [[ "$output" != *"secret"* ]]
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

@test "phi_registry: all four patterns active in one pass" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source $ZDOTDIR/lib/phi_scrubber.bash && printf 'SSN 123-45-6789 MRN: 99 DOB: 01/01/2000 postgresql://u:p@h/db' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" == *"[REDACTED-CONN]"* ]]
}
