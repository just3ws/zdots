package logs

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpAndUnknown(t *testing.T) {
	if rc := Run(nil); rc != 0 {
		t.Fatalf("empty args returned %d, want 0", rc)
	}
	if rc := Run([]string{"--help"}); rc != 0 {
		t.Fatalf("--help returned %d, want 0", rc)
	}
	if rc := Run([]string{"bogus"}); rc != 1 {
		t.Fatalf("bogus returned %d, want 1", rc)
	}
}

func TestListAndCheckJSON(t *testing.T) {
	tmp := t.TempDir()
	state := filepath.Join(tmp, "zsh")
	_ = os.MkdirAll(state, 0o755)
	_ = os.WriteFile(filepath.Join(state, "llama-server.log"), []byte("line1\nline2\nERROR boom\n"), 0o644)

	t.Setenv("XDG_STATE_HOME", tmp)
	t.Setenv("HOMEBREW_PREFIX", filepath.Join(tmp, "brew"))
	t.Setenv("ZDOTS_NO_OTEL", "1")

	capture := func(fn func() int) (int, string) {
		old := os.Stdout
		r, w, _ := os.Pipe()
		os.Stdout = w
		rc := fn()
		_ = w.Close()
		os.Stdout = old
		var buf [16384]byte
		n, _ := r.Read(buf[:])
		_ = r.Close()
		return rc, string(buf[:n])
	}

	rc, out := capture(func() int { return Run([]string{"list", "--json"}) })
	if rc != 0 {
		t.Fatalf("list --json rc=%d", rc)
	}
	var listRes struct {
		Sources []struct {
			Name   string `json:"name"`
			Exists bool   `json:"exists"`
			Status string `json:"status"`
		} `json:"sources"`
	}
	if err := json.Unmarshal([]byte(out), &listRes); err != nil {
		t.Fatalf("list --json invalid: %v\n%s", err, out)
	}
	if len(listRes.Sources) == 0 || !listRes.Sources[0].Exists || listRes.Sources[0].Status != "ok" {
		t.Fatalf("unexpected list --json sources: %+v", listRes.Sources)
	}

	rc, out = capture(func() int { return Run([]string{"check", "--json"}) })
	if rc != 0 {
		t.Fatalf("check --json rc=%d", rc)
	}
	var chkRes struct {
		AnyWarn bool `json:"any_warn"`
		AnyCrit bool `json:"any_crit"`
	}
	if err := json.Unmarshal([]byte(out), &chkRes); err != nil {
		t.Fatalf("check --json invalid: %v\n%s", err, out)
	}
	if chkRes.AnyWarn || chkRes.AnyCrit {
		t.Fatalf("unexpected warn/crit: %+v", chkRes)
	}

	rc, out = capture(func() int { return Run([]string{"grep", "error", "llama"}) })
	if rc != 0 || !strings.Contains(out, "ERROR boom") {
		t.Fatalf("grep failed: rc=%d out=%q", rc, out)
	}
}
