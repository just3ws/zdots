package otel

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

func TestTracerFlushSendsOTLP(t *testing.T) {
	var (
		mu       sync.Mutex
		received map[string]any
		path     string
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		mu.Lock()
		path = r.URL.Path
		_ = json.Unmarshal(b, &received)
		mu.Unlock()
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", srv.URL)
	t.Setenv("ZDOTS_TRACE_ID", "0123456789abcdef0123456789abcdef")

	tr := New("test")
	root := tr.Start("root.op", nil)
	root.SetAttr("ok", true)
	child := tr.Start("child.probe", root)
	child.SetAttr("latency_ms", 12)
	child.End(true, "")
	root.End(true, "")

	tr.Flush(500 * time.Millisecond)

	mu.Lock()
	defer mu.Unlock()
	if path != "/v1/traces" {
		t.Fatalf("got path %q, want /v1/traces", path)
	}
	rs, ok := received["resourceSpans"].([]any)
	if !ok || len(rs) != 1 {
		t.Fatalf("unexpected resourceSpans: %#v", received)
	}
}
