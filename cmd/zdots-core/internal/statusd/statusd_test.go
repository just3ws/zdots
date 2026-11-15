package statusd

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpAndLoopbackGuard(t *testing.T) {
	if rc := Run([]string{"--help"}); rc != 0 {
		t.Fatalf("--help rc=%d, want 0", rc)
	}
	t.Setenv("ZDOTS_STATUS_HOST", "0.0.0.0")
	if _, err := newServerEnv(); err == nil {
		t.Fatal("expected non-loopback host to be rejected")
	}
}

func TestRoutesAndBacklog404(t *testing.T) {
	tmp := t.TempDir()
	_ = os.MkdirAll(filepath.Join(tmp, "backlog", "tasks"), 0o755)
	_ = os.MkdirAll(filepath.Join(tmp, "backlog", "docs"), 0o755)
	_ = os.MkdirAll(filepath.Join(tmp, "etc", "themes"), 0o755)
	_ = os.WriteFile(filepath.Join(tmp, "VERSION"), []byte("0873026.M3\n"), 0o644)
	_ = os.WriteFile(filepath.Join(tmp, "etc", "system-topology.json"), []byte(`{"nodes":[],"links":[]}`), 0o644)
	_ = os.WriteFile(filepath.Join(tmp, "etc", "themes", "kanagawa-wave.yaml"), []byte("slug: kanagawa-wave\ntitle: Kanagawa Wave\npalette:\n  bg: \"1f1f28\"\ntokens:\n  bg: bg\nansi:\n  - bg\n"), 0o644)
	_ = os.WriteFile(filepath.Join(tmp, "backlog", "tasks", "Z-1.md"), []byte("---\nid: Z-1\ntitle: Test Task\nstatus: To Do\npriority: high\n---\nHello body\n"), 0o644)

	t.Setenv("ZDOTDIR", tmp)
	t.Setenv("ZDOTS_STATUS_HOST", "127.0.0.1")
	t.Setenv("ZDOTS_NO_OTEL", "1")
	t.Setenv("ZDOTS_AI_PORT", "59981")
	t.Setenv("ZDOTS_EMBED_PORT", "59982")
	t.Setenv("ZDOTS_O2_PORT", "59983")
	t.Setenv("ZDOTS_REDIS_PORT", "59984")

	env, err := newServerEnv()
	if err != nil {
		t.Fatal(err)
	}
	h := env.handler()

	// /healthz
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != 200 || rec.Body.String() != "ok" {
		t.Fatalf("/healthz => %d %q", rec.Code, rec.Body.String())
	}

	// /backlog
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/backlog", nil))
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "the plan of record") {
		t.Fatalf("/backlog => %d", rec.Code)
	}

	// /backlog/Z-1
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/backlog/Z-1", nil))
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), "Z-1 — Test Task") {
		t.Fatalf("/backlog/Z-1 => %d %q", rec.Code, rec.Body.String())
	}

	// /backlog/Z-99999999 -> 404
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/backlog/Z-99999999", nil))
	if rec.Code != 404 {
		t.Fatalf("/backlog/Z-99999999 => %d, want 404", rec.Code)
	}

	// /theme/palette.json
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/theme/palette.json", nil))
	if rec.Code != 200 {
		t.Fatalf("/theme/palette.json => %d", rec.Code)
	}
	var td themeData
	if err := json.Unmarshal(rec.Body.Bytes(), &td); err != nil || td.Slug != "kanagawa-wave" {
		t.Fatalf("unexpected palette.json: %v %+v", err, td)
	}
}
