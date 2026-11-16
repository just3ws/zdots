#!/usr/bin/env bats
# tests/otel_collector_install.bats — the collector tarball is checksum-pinned.
# Stub curl/uname on PATH; nothing is downloaded and no LaunchAgent is written.

setup() {
  load "setup.bash"
  setup_environment
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/stub"
  export STUB_OS=Darwin STUB_ARCH=arm64
  cat > "$BATS_TEST_TMPDIR/stub/curl" <<'SH'
#!/bin/sh
# curl -fL URL -o FILE: write a tarball that cannot match any pinned checksum.
while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { shift; printf 'not the release' > "$1"; }; shift; done
SH
  cat > "$BATS_TEST_TMPDIR/stub/uname" <<'SH'
#!/bin/sh
[ "$1" = "-s" ] && echo "$STUB_OS" || echo "$STUB_ARCH"
SH
  cat > "$BATS_TEST_TMPDIR/stub/tar" <<'SH'
#!/bin/sh
echo "tar ran" >&2; exit 1
SH
  chmod +x "$BATS_TEST_TMPDIR/stub/"*
}

run_install() {
  run env PATH="$BATS_TEST_TMPDIR/stub:$PATH" ZDOTDIR="$REPO_ROOT" "$REPO_ROOT/bin/otel-collector" install
}

@test "install refuses a tarball whose checksum does not match the pin" {
  run_install
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* ]]
  [[ "$output" != *"tar ran"* ]]
  [ ! -e "$HOME/.local/bin/otelcol-contrib" ]
}

@test "install fails closed for an OS/arch with no pinned checksum" {
  STUB_ARCH=riscv64 run_install
  [ "$status" -ne 0 ]
  [[ "$output" == *"no pinned checksum for darwin/riscv64"* ]]
  [[ "$output" != *"tar ran"* ]]
}

@test "ZDOTS_OTEL_ALLOW_UNVERIFIED=1 lets an unpinned OS/arch through to extraction" {
  STUB_ARCH=riscv64 ZDOTS_OTEL_ALLOW_UNVERIFIED=1 run_install
  [[ "$output" == *"installing unverified darwin/riscv64"* ]]
  [[ "$output" == *"tar ran"* ]]
}

@test "every pinned checksum is a sha256 for the four release platforms" {
  for p in darwin_arm64 darwin_amd64 linux_arm64 linux_amd64; do
    grep -Eq "^TARBALL_SHA256_${p}=\"[0-9a-f]{64}\"$" "$REPO_ROOT/bin/otel-collector"
  done
}
