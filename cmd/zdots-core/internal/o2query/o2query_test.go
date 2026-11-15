package o2query

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestParseDurationSeconds(t *testing.T) {
	cases := []struct {
		in   string
		want int64
	}{
		{"30s", 30},
		{"15m", 900},
		{"2h", 7200},
		{"1d", 86400},
		{"45", 45},
	}
	for _, tc := range cases {
		got, err := parseDurationSeconds(tc.in)
		if err != nil || got != tc.want {
			t.Fatalf("parseDurationSeconds(%q) = (%d, %v), want (%d, nil)", tc.in, got, err, tc.want)
		}
	}
	if _, err := parseDurationSeconds("bad"); err == nil {
		t.Fatal("expected error for invalid duration")
	}
}

func TestErrorsAndSQLWithMockServer(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		if r.URL.Path == "/api/default/_search" {
			_ = json.NewEncoder(w).Encode(map[string]any{
				"hits": []map[string]any{
					{
						"_timestamp":   int64(1700000000000000),
						"severity":     "ERROR",
						"service_name": "zdots-ctx",
						"body":         "boom",
						"trace_id":     "abcdef1234567890",
					},
				},
			})
			return
		}
		if r.URL.Path == "/api/default/streams" {
			_ = json.NewEncoder(w).Encode(map[string]any{
				"list": []map[string]any{{"name": "default"}},
			})
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()

	t.Setenv("ZDOTS_O2_ENDPOINT", srv.URL)
	stubAuth := func() (string, error) { return "secret-pass", nil }
	noopScrub := func(s string) (string, bool) { return s, true }
	fixedNow := func() time.Time { return time.Unix(1700000100, 0) }

	var out, errBuf bytes.Buffer
	code := runWithIO([]string{"errors", "--json"}, &out, &errBuf, false, stubAuth, noopScrub, fixedNow)
	if code != 0 {
		t.Fatalf("errors --json exit=%d stderr=%s", code, errBuf.String())
	}
	var rows []map[string]any
	if err := json.Unmarshal(out.Bytes(), &rows); err != nil {
		t.Fatalf("invalid json: %v\n%s", err, out.String())
	}
	if len(rows) != 1 || rows[0]["service"] != "zdots-ctx" {
		t.Fatalf("unexpected rows: %+v", rows)
	}

	out.Reset()
	errBuf.Reset()
	code = runWithIO([]string{"sql", "DELETE FROM default"}, &out, &errBuf, false, stubAuth, noopScrub, fixedNow)
	if code == 0 {
		t.Fatal("expected non-zero exit for non-SELECT sql")
	}

	out.Reset()
	errBuf.Reset()
	code = runWithIO([]string{"streams"}, &out, &errBuf, false, stubAuth, noopScrub, fixedNow)
	if code != 0 || !strings.Contains(out.String(), "default") {
		t.Fatalf("streams failed: code=%d out=%s err=%s", code, out.String(), errBuf.String())
	}
}
