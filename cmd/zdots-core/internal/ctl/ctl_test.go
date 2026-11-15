package ctl

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpAndArgGuards(t *testing.T) {
	if rc := Run([]string{"--help"}); rc != 0 {
		t.Fatalf("--help rc=%d, want 0", rc)
	}
	for _, sub := range []string{"up", "down", "reset", "install"} {
		if rc := Run([]string{sub, "--help"}); rc != 0 {
			t.Fatalf("%s --help rc=%d, want 0", sub, rc)
		}
		if rc := Run([]string{sub, "--unexpected"}); rc != 1 {
			t.Fatalf("%s --unexpected rc=%d, want 1", sub, rc)
		}
	}
	if rc := Run(nil); rc != 1 {
		t.Fatalf("empty args rc=%d, want 1", rc)
	}
	if rc := Run([]string{"not-a-real-command"}); rc != 1 {
		t.Fatalf("unknown cmd rc=%d, want 1", rc)
	}
}

func TestStatusJSONAndDownTraceLog(t *testing.T) {
	tmp := t.TempDir()
	xdgState := filepath.Join(tmp, "state")
	t.Setenv("XDG_STATE_HOME", xdgState)
	t.Setenv("ZDOTS_NO_OTEL", "1")
	t.Setenv("ZDOTS_AI_PORT", "59991")
	t.Setenv("ZDOTS_EMBED_PORT", "59992")
	t.Setenv("ZDOTS_O2_PORT", "59993")
	t.Setenv("ZDOTS_REDIS_PORT", "59994")

	old := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w
	rc := Run([]string{"status", "--json"})
	_ = w.Close()
	os.Stdout = old
	var buf [8192]byte
	n, _ := r.Read(buf[:])
	_ = r.Close()
	out := string(buf[:n])

	if rc != 0 {
		t.Fatalf("status --json rc=%d", rc)
	}
	var m map[string]any
	if err := json.Unmarshal([]byte(out), &m); err != nil {
		t.Fatalf("status --json invalid JSON: %v\n%s", err, out)
	}
	for _, k := range []string{"core_ready", "ai_server", "ai_endpoint", "otlp_endpoint"} {
		if _, ok := m[k]; !ok {
			t.Fatalf("missing key %q in status --json: %s", k, out)
		}
	}

	if rc := Run([]string{"down"}); rc != 0 {
		t.Fatalf("down rc=%d", rc)
	}
	tb, err := os.ReadFile(filepath.Join(xdgState, "zsh", "traces.jsonl"))
	if err != nil {
		t.Fatalf("expected traces.jsonl: %v", err)
	}
	if !strings.Contains(string(tb), `"event":"platform_down"`) {
		t.Fatalf("expected platform_down in traces.jsonl, got %s", string(tb))
	}
}
