package ctlstatus

import (
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHostPortFromURL(t *testing.T) {
	if got := hostPortFromURL("http://127.0.0.1:11500", "fallback"); got != "127.0.0.1:11500" {
		t.Fatalf("got %q", got)
	}
	if got := hostPortFromURL("https://example.com", "fallback"); got != "example.com:443" {
		t.Fatalf("got %q", got)
	}
}

func TestHTTPOkAndTCPOpen(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"data":[{"id":"qwen3-8b"}]}`))
	}))
	defer srv.Close()

	if !httpOK(srv.URL, 1e9) {
		t.Fatal("expected httpOK true")
	}
	if body := httpBody(srv.URL, 1e9); len(body) == 0 {
		t.Fatal("expected non-empty body")
	}
	if !tcpOpen(hostPortFromURL(srv.URL, ""), 1e9) {
		t.Fatal("expected tcpOpen true")
	}
}

func TestRedisPingMock(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		var b [16]byte
		_, _ = c.Read(b[:])
		_, _ = c.Write([]byte("+PONG\r\n"))
	}()

	if !redisPing(ln.Addr().String(), 1e9) {
		t.Fatal("expected redisPing true")
	}
}
