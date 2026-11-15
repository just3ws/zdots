package zsvc

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestHelpAndErrors(t *testing.T) {
	if rc := Run(nil); rc != 1 {
		t.Fatalf("empty args rc=%d, want 1", rc)
	}
	if rc := Run([]string{"--help"}); rc != 0 {
		t.Fatalf("--help rc=%d, want 0", rc)
	}
	if rc := Run([]string{"bogus"}); rc != 1 {
		t.Fatalf("bogus cmd rc=%d, want 1", rc)
	}
	if rc := Run([]string{"wait", "llama", "--timeout", "0"}); rc != 1 {
		t.Fatalf("wait --timeout 0 rc=%d, want 1", rc)
	}
	if rc := Run([]string{"start", "nonexistent-svc"}); rc != 1 {
		t.Fatalf("unknown svc rc=%d, want 1", rc)
	}
}

func TestMapAndLogsAllJSON(t *testing.T) {
	t.Setenv("ZDOTS_NO_OTEL", "1")
	capture := func(fn func() int) (int, string) {
		old := os.Stdout
		r, w, _ := os.Pipe()
		os.Stdout = w
		rc := fn()
		_ = w.Close()
		os.Stdout = old
		var buf [32768]byte
		n, _ := r.Read(buf[:])
		_ = r.Close()
		return rc, string(buf[:n])
	}

	rc, out := capture(func() int { return Run([]string{"map", "--json"}) })
	if rc != 0 {
		t.Fatalf("map --json rc=%d", rc)
	}
	var m struct {
		Services []struct {
			Name    string `json:"name"`
			Purpose string `json:"purpose"`
		} `json:"services"`
	}
	if err := json.Unmarshal([]byte(out), &m); err != nil {
		t.Fatalf("map --json invalid: %v\n%s", err, out)
	}
	if len(m.Services) < 7 {
		t.Fatalf("expected >= 7 services, got %d", len(m.Services))
	}

	rc, out = capture(func() int { return Run([]string{"map", "db", "--json"}) })
	if rc != 0 || !strings.Contains(out, `"name":"postgres"`) {
		t.Fatalf("alias resolution db -> postgres failed: rc=%d out=%s", rc, out)
	}

	rc, out = capture(func() int { return Run([]string{"logs", "all", "--json"}) })
	if rc != 0 || !strings.Contains(out, `"sources"`) {
		t.Fatalf("logs all --json failed: rc=%d out=%s", rc, out)
	}
}
