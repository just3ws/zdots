package ctlstatus

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

// Status mirrors the JSON schema emitted by `zdots-ctl status --json`.
type Status struct {
	CoreReady         bool   `json:"core_ready"`
	Colima            bool   `json:"colima"`
	Jaeger            bool   `json:"jaeger"`
	OpenObserve       bool   `json:"openobserve"`
	OTelCollector     bool   `json:"otel_collector"`
	AIServer          bool   `json:"ai_server"`
	AIHTTPHealthy     bool   `json:"ai_http_healthy"`
	AISocketListening bool   `json:"ai_socket_listening"`
	EmbedServer       bool   `json:"embed_server"`
	AIModel           string `json:"ai_model"`
	IntelligenceSuite bool   `json:"intelligence_suite"`
	Cache             bool   `json:"cache"`
	Worker            bool   `json:"worker"`
	O2URL             string `json:"o2_url"`
	JaegerURL         string `json:"jaeger_url"`
	AIEndpoint        string `json:"ai_endpoint"`
	EmbedEndpoint     string `json:"embed_endpoint"`
	OTLPEndpoint      string `json:"otlp_endpoint"`
	RedisHost         string `json:"redis_host"`
	RedisPort         int    `json:"redis_port"`
}

// Probe concurrently checks all platform services and returns the aggregate status.
func Probe(zdotdir string) Status {
	return ProbeWithTracer(zdotdir, nil, nil)
}

func startProbeSpan(tr *otel.Tracer, parent *otel.Span, name string) *otel.Span {
	if tr == nil {
		return nil
	}
	return tr.Start(name, parent)
}

// ProbeWithTracer concurrently checks all platform services while optionally recording child spans.
func ProbeWithTracer(zdotdir string, tr *otel.Tracer, parent *otel.Span) Status {
	aiEndpoint := envOr("ZDOTS_AI_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_AI_HOST", "127.0.0.1"), envOr("ZDOTS_AI_PORT", "11500")))
	embedEndpoint := envOr("ZDOTS_AI_EMBED_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_EMBED_HOST", "127.0.0.1"), envOr("ZDOTS_EMBED_PORT", "11501")))
	otlpEndpoint := envOr("ZDOTS_OTLP_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_OTEL_HOST", "127.0.0.1"), envOr("ZDOTS_OTEL_HTTP_PORT", "4318")))
	o2Endpoint := envOr("ZDOTS_O2_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_O2_HOST", "127.0.0.1"), envOr("ZDOTS_O2_PORT", "5080")))
	jaegerEndpoint := envOr("ZDOTS_JAEGER_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_JAEGER_HOST", "127.0.0.1"), envOr("ZDOTS_JAEGER_UI_PORT", "16686")))
	redisHost := envOr("ZDOTS_REDIS_HOST", "127.0.0.1")
	redisPort := 6379
	if p, err := strconv.Atoi(envOr("ZDOTS_REDIS_PORT", "6379")); err == nil && p > 0 {
		redisPort = p
	}

	st := Status{
		AIModel:       "unknown",
		O2URL:         o2Endpoint,
		JaegerURL:     jaegerEndpoint,
		AIEndpoint:    aiEndpoint,
		EmbedEndpoint: embedEndpoint,
		OTLPEndpoint:  otlpEndpoint,
		RedisHost:     redisHost,
		RedisPort:     redisPort,
	}

	var wg sync.WaitGroup

	// 1. llama.cpp HTTP health + /v1/models
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.llama_http")
		if httpOK(aiEndpoint+"/health", 2*time.Second) {
			st.AIServer = true
			st.AIHTTPHealthy = true
			st.AIModel = "local"
			if body := httpBody(aiEndpoint+"/v1/models", 2*time.Second); len(body) > 0 {
				var m struct {
					Data []struct {
						ID string `json:"id"`
					} `json:"data"`
				}
				if json.Unmarshal(body, &m) == nil && len(m.Data) > 0 && m.Data[0].ID != "" {
					st.AIModel = m.Data[0].ID
				}
			}
		}
		sp.SetAttr("healthy", st.AIServer)
		sp.SetAttr("ai_model", st.AIModel)
		sp.End(st.AIServer, "")
	}()

	// 2. llama.cpp loopback TCP socket listening
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.llama_tcp")
		if addr := hostPortFromURL(aiEndpoint, "127.0.0.1:11500"); tcpOpen(addr, 500*time.Millisecond) {
			st.AISocketListening = true
		}
		sp.End(st.AISocketListening, "")
	}()

	// 3. embed server HTTP health
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.embed")
		st.EmbedServer = httpOK(embedEndpoint+"/health", 2*time.Second)
		sp.End(st.EmbedServer, "")
	}()

	// 4. OpenObserve HTTP health (retired — kept for JSON schema compatibility)
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.openobserve")
		st.OpenObserve = httpOK(o2Endpoint+"/healthz", 2*time.Second)
		sp.End(st.OpenObserve, "")
	}()

	// 4b. Jaeger HTTP health
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.jaeger")
		st.Jaeger = httpOK(jaegerEndpoint+"/", 2*time.Second)
		sp.End(st.Jaeger, "")
	}()

	// 5. otel-collector launchd
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.otel_launchd")
		st.OTelCollector = launchdRunning("com.zdots.otel-collector")
		sp.End(st.OTelCollector, "")
	}()

	// 6. worker launchd
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.worker_launchd")
		st.Worker = launchdRunning("com.zdots.worker")
		sp.End(st.Worker, "")
	}()

	// 7. Colima
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.colima")
		colimaBin := filepath.Join(zdotdir, "bin", "colima-status")
		if info, err := os.Stat(colimaBin); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			st.Colima = exec.CommandContext(ctx, colimaBin, "health").Run() == nil
			sp.End(st.Colima, "")
			return
		}
		if _, err := exec.LookPath("colima-status"); err == nil {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			st.Colima = exec.CommandContext(ctx, "colima-status", "health").Run() == nil
		}
		sp.End(st.Colima, "")
	}()

	// 8. Intelligence suite (Postgres `my`)
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.postgres")
		if _, err := exec.LookPath("pg_isready"); err == nil {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			if exec.CommandContext(ctx, "pg_isready", "-q", "-d", "my").Run() == nil {
				st.IntelligenceSuite = true
				sp.End(true, "")
				return
			}
		}
		st.IntelligenceSuite = tcpOpen("127.0.0.1:5432", 500*time.Millisecond)
		sp.End(st.IntelligenceSuite, "")
	}()

	// 9. Redis cache
	wg.Add(1)
	go func() {
		defer wg.Done()
		sp := startProbeSpan(tr, parent, "probe.redis")
		st.Cache = redisPing(net.JoinHostPort(redisHost, strconv.Itoa(redisPort)), 500*time.Millisecond)
		sp.End(st.Cache, "")
	}()

	wg.Wait()

	aiMode := envOr("ZDOTS_AI_MODE", "local")
	if st.IntelligenceSuite && (st.AIServer || aiMode == "none") {
		st.CoreReady = true
	}
	return st
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}

func httpOK(rawURL string, timeout time.Duration) bool {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(rawURL)
	if err != nil {
		return false
	}
	_ = resp.Body.Close()
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

func httpBody(rawURL string, timeout time.Duration) []byte {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(rawURL)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil
	}
	var buf [64 * 1024]byte
	n, _ := resp.Body.Read(buf[:])
	return buf[:n]
}

func hostPortFromURL(rawURL, fallback string) string {
	u, err := url.Parse(rawURL)
	if err != nil || u.Host == "" {
		return fallback
	}
	if strings.Contains(u.Host, ":") {
		return u.Host
	}
	if u.Scheme == "https" {
		return u.Host + ":443"
	}
	return u.Host + ":80"
}

func tcpOpen(addr string, timeout time.Duration) bool {
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}

func redisPing(addr string, timeout time.Duration) bool {
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return false
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(timeout))
	if _, err := conn.Write([]byte("PING\r\n")); err != nil {
		return false
	}
	var buf [16]byte
	n, err := conn.Read(buf[:])
	return err == nil && strings.Contains(string(buf[:n]), "PONG")
}

func launchdRunning(label string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "launchctl", "list", label).Output()
	return err == nil && strings.Contains(string(out), `"PID"`)
}
