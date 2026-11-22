package otel

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/config"
)

// Tracer collects spans in memory and flushes them as OTLP/HTTP JSON (/v1/traces).
type Tracer struct {
	endpoint string
	service  string
	traceID  string

	mu    sync.Mutex
	spans []spanRecord
}

type spanRecord struct {
	traceID    string
	spanID     string
	parentID   string
	name       string
	startNano  int64
	endNano    int64
	ok         bool
	errMsg     string
	attributes map[string]any
}

// Span represents an in-flight operation.
type Span struct {
	tracer    *Tracer
	spanID    string
	parentID  string
	name      string
	startTime time.Time
	attrs     map[string]any
}

// New creates a Tracer for the given applet/service name.
func New(applet string) *Tracer {
	ep := config.Load(config.Zdotdir()).OTLPEndpoint()
	tid := os.Getenv("ZDOTS_TRACE_ID")
	if !isHexLen(tid, 32) || tid == "00000000000000000000000000000000" {
		tid = randomHex(16)
	}
	return &Tracer{
		endpoint: ep,
		service:  "zdots-core." + applet,
		traceID:  tid,
	}
}

// Start begins a root or child span.
func (t *Tracer) Start(name string, parent *Span) *Span {
	pid := ""
	if parent != nil {
		pid = parent.spanID
	}
	return &Span{
		tracer:    t,
		spanID:    randomHex(8),
		parentID:  pid,
		name:      name,
		startTime: time.Now(),
		attrs:     make(map[string]any),
	}
}

// SetAttr attaches an attribute to the span.
func (s *Span) SetAttr(k string, v any) {
	if s == nil {
		return
	}
	s.attrs[k] = v
}

// End finishes the span and records it on the tracer.
func (s *Span) End(ok bool, errMsg string) {
	if s == nil || s.tracer == nil {
		return
	}
	rec := spanRecord{
		traceID:    s.tracer.traceID,
		spanID:     s.spanID,
		parentID:   s.parentID,
		name:       s.name,
		startNano:  s.startTime.UnixNano(),
		endNano:    time.Now().UnixNano(),
		ok:         ok,
		errMsg:     errMsg,
		attributes: s.attrs,
	}
	s.tracer.mu.Lock()
	s.tracer.spans = append(s.tracer.spans, rec)
	s.tracer.mu.Unlock()
}

// Flush posts recorded spans to OTLP/HTTP /v1/traces with a tight timeout.
// Failures are silently ignored so observability never blocks or breaks CLI execution.
func (t *Tracer) Flush(timeout time.Duration) {
	if t == nil || os.Getenv("ZDOTS_NO_OTEL") == "1" || os.Getenv("ZDOTS_OTEL_ENABLED") == "0" {
		return
	}
	t.mu.Lock()
	if len(t.spans) == 0 {
		t.mu.Unlock()
		return
	}
	spans := make([]spanRecord, len(t.spans))
	copy(spans, t.spans)
	t.mu.Unlock()

	payload := buildOTLPPayload(t.service, spans)
	body, err := json.Marshal(payload)
	if err != nil {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.endpoint+"/v1/traces", bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: timeout}).Do(req)
	if err == nil {
		_ = resp.Body.Close()
	}
}

func buildOTLPPayload(service string, spans []spanRecord) map[string]any {
	otlpSpans := make([]map[string]any, 0, len(spans))
	for _, s := range spans {
		statusCode := 1 // STATUS_CODE_OK
		if !s.ok {
			statusCode = 2 // STATUS_CODE_ERROR
		}
		st := map[string]any{"code": statusCode}
		if s.errMsg != "" {
			st["message"] = s.errMsg
		}
		sp := map[string]any{
			"traceId":           s.traceID,
			"spanId":            s.spanID,
			"name":              s.name,
			"kind":              1, // SPAN_KIND_INTERNAL
			"startTimeUnixNano": strconv.FormatInt(s.startNano, 10),
			"endTimeUnixNano":   strconv.FormatInt(s.endNano, 10),
			"attributes":        encodeAttrs(s.attributes),
			"status":            st,
		}
		if s.parentID != "" {
			sp["parentSpanId"] = s.parentID
		}
		otlpSpans = append(otlpSpans, sp)
	}

	return map[string]any{
		"resourceSpans": []map[string]any{
			{
				"resource": map[string]any{
					"attributes": encodeAttrs(map[string]any{
						"service.name": service,
					}),
				},
				"scopeSpans": []map[string]any{
					{
						"scope": map[string]any{
							"name": "zdots-core",
						},
						"spans": otlpSpans,
					},
				},
			},
		},
	}
}

func encodeAttrs(m map[string]any) []map[string]any {
	out := make([]map[string]any, 0, len(m))
	for k, v := range m {
		var val map[string]any
		switch tv := v.(type) {
		case string:
			val = map[string]any{"stringValue": tv}
		case bool:
			val = map[string]any{"boolValue": tv}
		case int:
			val = map[string]any{"intValue": strconv.Itoa(tv)}
		case int64:
			val = map[string]any{"intValue": strconv.FormatInt(tv, 10)}
		default:
			continue
		}
		out = append(out, map[string]any{"key": k, "value": val})
	}
	return out
}

func randomHex(nBytes int) string {
	b := make([]byte, nBytes)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func isHexLen(s string, want int) bool {
	if len(s) != want {
		return false
	}
	for _, r := range s {
		if !((r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F')) {
			return false
		}
	}
	return true
}
