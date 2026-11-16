package swiftbar

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpAndUnknownFlag(t *testing.T) {
	var out, errBuf bytes.Buffer
	code := runWithIO([]string{"--help"}, &out, &errBuf, func() []processInfo { return nil })
	if code != 0 || !strings.Contains(out.String(), "Usage: zdots-swiftbar") {
		t.Fatalf("unexpected help result: code=%d out=%s", code, out.String())
	}

	out.Reset()
	errBuf.Reset()
	code = runWithIO([]string{"--bad"}, &out, &errBuf, func() []processInfo { return nil })
	if code != 2 || !strings.Contains(errBuf.String(), "unknown argument") {
		t.Fatalf("unexpected bad-flag result: code=%d err=%s", code, errBuf.String())
	}
}

func TestDoctorDecoupledFromCheckAndMissingModel(t *testing.T) {
	stateHome := t.TempDir()
	zshState := filepath.Join(stateHome, "zsh")
	if err := os.MkdirAll(zshState, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(zshState, "zdots-watch.state"),
		[]byte("ts=2026-10-07T00:00:00\nrc=0\npass=43\nwarn=0\nfail=0\ncaps_errors=0\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(zshState, "zdots-watch-check.state"),
		[]byte("ts=2026-10-07T00:00:00\nrc=1\nfail|some test\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	modelsDir := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateHome)
	t.Setenv("ZDOTS_WHISPER_MODELS_DIR", modelsDir)
	t.Setenv("ZDOTS_WHISPER_MODEL_FILE", "nonexistent.bin")

	var out, errBuf bytes.Buffer
	code := runWithIO(nil, &out, &errBuf, func() []processInfo { return nil })
	if code != 0 {
		t.Fatalf("expected exit 0, got %d (stderr=%s)", code, errBuf.String())
	}
	s := out.String()
	if !strings.Contains(s, "Platform Doctor: 43 pass · 0 warn · 0 fail (Healthy)") {
		t.Fatalf("expected healthy doctor line, got:\n%s", s)
	}
	if !strings.Contains(s, "Test Suite: rc=1") {
		t.Fatalf("expected Test Suite: rc=1, got:\n%s", s)
	}
	if !strings.Contains(s, "🎙️ Transcription:") {
		t.Fatalf("missing transcription section")
	}
}

// A host that never set transcription up (no models, no ingest, no jobs) shows
// it as not set up, and keeps it out of the menu-bar title.
func TestTranscriptionNotSetUpStaysQuiet(t *testing.T) {
	stateHome := t.TempDir()
	zshState := filepath.Join(stateHome, "zsh")
	if err := os.MkdirAll(zshState, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(zshState, "zdots-watch.state"),
		[]byte("ts=2026-11-16T00:00:00\nrc=0\npass=40\nwarn=0\nfail=0\ncaps_errors=0\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_STATE_HOME", stateHome)
	t.Setenv("ZDOTS_WHISPER_MODELS_DIR", t.TempDir())

	var out, errBuf bytes.Buffer
	if code := runWithIO(nil, &out, &errBuf, func() []processInfo { return nil }); code != 0 {
		t.Fatalf("exit %d: %s", code, errBuf.String())
	}
	s := out.String()
	title, _, _ := strings.Cut(s, "\n")
	if title != "🟢" {
		t.Fatalf("title = %q, want just the platform glyph", title)
	}
	if !strings.Contains(s, "🎙️ Transcription: not set up | color=gray") {
		t.Fatalf("expected a gray not-set-up transcription line, got:\n%s", s)
	}
}

// Postgres, gemstash (port from ~/.gemstash/config.yml) and Jaeger appear in
// the subsystem list from the process table alone.
func TestSubsystemsIncludePostgresGemstashJaeger(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("ZDOTS_WHISPER_MODELS_DIR", t.TempDir())
	if err := os.MkdirAll(filepath.Join(home, ".gemstash"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".gemstash", "config.yml"),
		[]byte("---\n:bind: tcp://127.0.0.1:44292\n:db_adapter: postgres\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	procs := []processInfo{
		{pid: 10, args: "/opt/homebrew/opt/postgresql@17/bin/postgres -D /opt/homebrew/var/postgresql@17"},
		{pid: 11, args: "puma 7.2.1 (tcp://127.0.0.1:44292) [zsh]"},
		{pid: 12, args: "/Users/u/.local/bin/jaeger --config /x/etc/jaeger.yaml"},
	}
	var out, errBuf bytes.Buffer
	if code := runWithIO(nil, &out, &errBuf, func() []processInfo { return procs }); code != 0 {
		t.Fatalf("exit %d: %s", code, errBuf.String())
	}
	s := out.String()
	for _, want := range []string{
		"🐘 Postgres (5432): Running | color=green",
		"💎 gemstash (44292): Running | color=green",
		"🔭 Jaeger (16686): Active | color=green",
	} {
		if !strings.Contains(s, want) {
			t.Fatalf("missing %q in:\n%s", want, s)
		}
	}

	out.Reset()
	if code := runWithIO(nil, &out, &errBuf, func() []processInfo { return nil }); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if !strings.Contains(out.String(), "💎 gemstash (44292): Stopped | color=gray") {
		t.Fatalf("expected stopped gemstash, got:\n%s", out.String())
	}
}
