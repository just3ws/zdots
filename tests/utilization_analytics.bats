#!/usr/bin/env bats
# tests/utilization_analytics.bats — Utilization analytics instrumentation regression suite

setup() {
  load "setup.bash"
  setup_environment
  
  export TEST_TRACES_DIR=$(mktemp -d)
  export XDG_STATE_HOME="$TEST_TRACES_DIR"
  export TEST_TRACES_FILE="$XDG_STATE_HOME/zsh/traces.jsonl"
  mkdir -p "$(dirname "$TEST_TRACES_FILE")"
  touch "$TEST_TRACES_FILE"
  
  export STUB_BIN="$TEST_TRACES_DIR/bin"
  mkdir -p "$STUB_BIN"
}

teardown() {
  rm -rf "$TEST_TRACES_DIR"
}

@test "analytics: ztask start logs task_start" {
  # Stub dependencies
  cat > "$STUB_BIN/zdots-ctl" <<EOF
#!/bin/sh
exit 0
EOF
  cat > "$STUB_BIN/zdots-ctx" <<EOF
#!/bin/sh
exit 0
EOF
  cat > "$STUB_BIN/backlog" <<EOF
#!/bin/sh
exit 0
EOF
  chmod +x "$STUB_BIN/zdots-ctl" "$STUB_BIN/zdots-ctx" "$STUB_BIN/backlog"
  
  export ZTASK_ZDOTS_CTL="$STUB_BIN/zdots-ctl"
  export ZTASK_ZDOTS_CTX="$STUB_BIN/zdots-ctx"
  export ZTASK_BACKLOG_BIN="$STUB_BIN/backlog"
  export ZTASK_TASKS_DIR="$TEST_TRACES_DIR/fake_tasks"
  
  mkdir -p "$ZTASK_TASKS_DIR"
  echo "id: z-999" > "$ZTASK_TASKS_DIR/z-999.md"

  export DATABASE_URL="mock"
  PATH="$STUB_BIN:$PATH" run "$ZDOTDIR/bin/ztask" start z-999
  grep -q "task_start" "$TEST_TRACES_FILE"
}

@test "analytics: zpi logs ai_query" {
  cat > "$STUB_BIN/pi" <<EOF
#!/bin/sh
exit 0
EOF
  cat > "$STUB_BIN/pi-ctx-brief" <<EOF
#!/bin/sh
exit 0
EOF
  chmod +x "$STUB_BIN/pi" "$STUB_BIN/pi-ctx-brief"

  run zsh -c "
    export ZDOTDIR='$ZDOTDIR'
    export XDG_STATE_HOME='$XDG_STATE_HOME'
    export PATH='$STUB_BIN:\$PATH'
    zdots_ai_gated_endpoint() { echo 'http://localhost'; }
    source '$ZDOTDIR/providers/trace/local.zsh'
    zdots_trace_init
    source '$ZDOTDIR/providers/tools/pi.zsh'
    zpi 'test prompt'
  "
  grep -q "ai_query" "$TEST_TRACES_FILE"
}

@test "analytics: zdots-ask logs ai_query" {
  cat > "$STUB_BIN/yq" <<EOF
#!/bin/sh
echo "default\t.*"
EOF
  cat > "$STUB_BIN/fabric-ai" <<EOF
#!/bin/sh
exit 0
EOF
  chmod +x "$STUB_BIN/yq" "$STUB_BIN/fabric-ai"

  export ZDOTDIR="$ZDOTDIR"
  PATH="$STUB_BIN:$PATH" run "$ZDOTDIR/bin/zdots-ask" "test prompt"
  grep -q "ai_query" "$TEST_TRACES_FILE"
}

@test "analytics: zdots-doctor logs doctor_check" {
  cat > "$STUB_BIN/zdots-ctl" <<EOF
#!/bin/sh
echo "all checks passed"
exit 0
EOF
  chmod +x "$STUB_BIN/zdots-ctl"

  PATH="$STUB_BIN:$PATH" run "$ZDOTDIR/bin/zdots-doctor" --no-runtime
  grep -q "doctor_check" "$TEST_TRACES_FILE"
}

@test "analytics: zdots-ctl up/down logs platform events" {
  mkdir -p "$TEST_TRACES_DIR/fake_zdots/bin"
  cp "$ZDOTDIR/bin/zdots-ctl" "$TEST_TRACES_DIR/fake_zdots/bin/"
  
  for cmd in local-ci otel-collector llama-ctl zdots-ctx; do
    cat > "$TEST_TRACES_DIR/fake_zdots/bin/$cmd" <<EOF
#!/bin/sh
exit 0
EOF
    chmod +x "$TEST_TRACES_DIR/fake_zdots/bin/$cmd"
  done

  cat > "$STUB_BIN/curl" <<EOF
#!/bin/sh
exit 1
EOF
  chmod +x "$STUB_BIN/curl"

  PATH="$STUB_BIN:$PATH" run "$TEST_TRACES_DIR/fake_zdots/bin/zdots-ctl" up
  grep -q "platform_up" "$TEST_TRACES_FILE"
}

@test "analytics: bootstrap logs bootstrap events" {
  cat > "$STUB_BIN/brew" <<EOF
#!/bin/sh
echo "Homebrew 4.0.0"
exit 0
EOF
  chmod +x "$STUB_BIN/brew"

  PATH="$STUB_BIN:$PATH" run "$ZDOTDIR/bin/bootstrap" --help
  grep -q "bootstrap_start" "$TEST_TRACES_FILE"
}

@test "analytics: zdots-ctx stats summarizes traces" {
  cat > "$TEST_TRACES_FILE" <<EOF
{"ts":"2026-06-01T08:00:00-0500","sid":"s","spid":"p","event":"exec","data":"cmd=ls"}
{"ts":"2026-06-01T08:01:00-0500","sid":"s","spid":"p","event":"error","data":"status=1"}
{"ts":"2026-06-01T08:02:00-0500","sid":"s","spid":"p","event":"ai_query","data":"tool=zdots-ask,domain=shell"}
EOF

  export ZDOTDIR="$ZDOTDIR"

  run "$ZDOTDIR/bin/zdots-ctx" stats

  [ "$status" -eq 0 ]
  [[ "$output" == *"AI Tool Usage:"* ]]
  [[ "$output" == *"zdots-ask"* ]]
  [[ "$output" == *"Error Rate      : 100.00%"* ]]
}
