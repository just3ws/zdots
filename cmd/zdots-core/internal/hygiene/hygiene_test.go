package hygiene

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestHelpAndUnknownFlag(t *testing.T) {
	var out, errBuf bytes.Buffer
	code := runWithIO([]string{"--help"}, &out, &errBuf, false)
	if code != 0 || !strings.Contains(out.String(), "zdots-hygiene") {
		t.Fatalf("help failed: code=%d out=%s", code, out.String())
	}

	out.Reset()
	errBuf.Reset()
	code = runWithIO([]string{"--bogus"}, &out, &errBuf, false)
	if code == 0 || !strings.Contains(errBuf.String(), "unknown option") {
		t.Fatalf("expected non-zero on unknown flag, got code=%d err=%s", code, errBuf.String())
	}
}

func TestScanHomeDryRunAndApply(t *testing.T) {
	home := t.TempDir()
	now := time.Now()
	old40d := now.Add(-40 * 24 * time.Hour)
	old5d := now.Add(-5 * 24 * time.Hour)

	logDir := filepath.Join(home, ".local", "state", "zsh")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		t.Fatal(err)
	}
	staleDiag := filepath.Join(logDir, "collector-diag-test.jsonl")
	if err := os.WriteFile(staleDiag, []byte("12345"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(staleDiag, old40d, old40d); err != nil {
		t.Fatal(err)
	}

	scratchDir := filepath.Join(home, ".local", "state", "just3ws", "scratch")
	if err := os.MkdirAll(scratchDir, 0o755); err != nil {
		t.Fatal(err)
	}
	staleWav := filepath.Join(scratchDir, "clip.wav")
	if err := os.WriteFile(staleWav, []byte("abcdef"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(staleWav, old5d, old5d); err != nil {
		t.Fatal(err)
	}

	npxBad := filepath.Join(home, ".npm", "_npx", "not-a-hex-dir")
	if err := os.MkdirAll(npxBad, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(npxBad, old40d, old40d); err != nil {
		t.Fatal(err)
	}

	npxGood := filepath.Join(home, ".npm", "_npx", "0123456789abcdef")
	if err := os.MkdirAll(npxGood, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(npxGood, "package.json"), []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(npxGood, old40d, old40d); err != nil {
		t.Fatal(err)
	}

	var errBuf bytes.Buffer
	res := scanHome(home, now, &errBuf)
	if len(res.staleDiagFiles) != 1 || res.staleDiagBytes != 5 {
		t.Fatalf("unexpected staleDiag: %+v", res)
	}
	if len(res.staleScratchFiles) != 1 || res.staleScratchBytes != 6 {
		t.Fatalf("unexpected staleScratch: %+v", res)
	}
	if len(res.staleNpxDirs) != 1 {
		t.Fatalf("unexpected staleNpxDirs: %+v", res.staleNpxDirs)
	}
	if !strings.Contains(errBuf.String(), "signature mismatch") {
		t.Fatalf("expected signature mismatch warning, got: %s", errBuf.String())
	}

	t.Setenv("HOME", home)
	var out bytes.Buffer
	errBuf.Reset()
	code := runWithIO(nil, &out, &errBuf, false)
	if code != 0 || !strings.Contains(out.String(), "dry run") || !strings.Contains(out.String(), "Candidate Evictions:") {
		t.Fatalf("dry run unexpected: code=%d out=%s", code, out.String())
	}
}
