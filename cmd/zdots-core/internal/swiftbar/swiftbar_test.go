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
