package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpAndUnknownFlag(t *testing.T) {
	if rc := Run([]string{"--help"}); rc != 0 {
		t.Fatalf("--help returned %d, want 0", rc)
	}
	if rc := Run([]string{"--bogus-flag"}); rc != 1 {
		t.Fatalf("--bogus-flag returned %d, want 1", rc)
	}
}

func TestJSONOutputAndTraceLog(t *testing.T) {
	tmp := t.TempDir()
	xdgState := filepath.Join(tmp, "state")
	zdotdir := filepath.Join(tmp, "zdots")
	_ = os.MkdirAll(filepath.Join(zdotdir, "bin"), 0o755)
	_ = os.MkdirAll(filepath.Join(zdotdir, "etc"), 0o755)
	_ = os.WriteFile(filepath.Join(zdotdir, "VERSION"), []byte("0873026.M3\n"), 0o644)
	_ = os.WriteFile(filepath.Join(zdotdir, "etc", "otel-collector.yaml"), []byte("exporters:\n  file/logs:\n  file/metrics:\n"), 0o644)

	t.Setenv("ZDOTDIR", zdotdir)
	t.Setenv("XDG_STATE_HOME", xdgState)
	t.Setenv("ZDOTS_NO_OTEL", "1")
	t.Setenv("ZDOTS_CONTEXT", "home")
	t.Setenv("_DOCTOR_PEER", "1")
	t.Setenv("HOMEBREW_PREFIX", "/opt/homebrew")

	// Capture stdout
	oldStdout := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = w

	rc := Run([]string{"--no-runtime", "--json"})

	_ = w.Close()
	os.Stdout = oldStdout

	var buf [16384]byte
	n, _ := r.Read(buf[:])
	_ = r.Close()
	out := string(buf[:n])

	var rep jsonReport
	if err := json.Unmarshal([]byte(out), &rep); err != nil {
		t.Fatalf("invalid JSON output: %v\noutput=%s", err, out)
	}
	if rep.Status != "pass" && rep.Status != "fail" {
		t.Fatalf("unexpected status: %q", rep.Status)
	}
	if rc < 0 {
		t.Fatalf("unexpected negative rc: %d", rc)
	}

	traceBytes, err := os.ReadFile(filepath.Join(xdgState, "zsh", "traces.jsonl"))
	if err != nil {
		t.Fatalf("expected traces.jsonl to be written: %v", err)
	}
	if !strings.Contains(string(traceBytes), `"event":"doctor_check"`) {
		t.Fatalf("expected doctor_check event in traces.jsonl, got %s", string(traceBytes))
	}
}
