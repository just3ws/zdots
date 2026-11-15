// Package o2query implements the zdots-o2-query OpenObserve query applet.
package o2query

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

var selectRe = regexp.MustCompile(`(?i)^\s*select\s+`)

type palette struct {
	rst, bold, dim, red, yel string
}

func newPalette(tty bool) palette {
	if !tty {
		return palette{}
	}
	return palette{
		rst:  "\033[0m",
		bold: "\033[1m",
		dim:  "\033[2m",
		red:  "\033[0;31m",
		yel:  "\033[0;33m",
	}
}

type options struct {
	endpoint  string
	org       string
	stream    string
	rootEmail string
	since     string
	limit     int
	ms        int64
	grep      string
	sqlType   string
	jsonOut   bool
	noScrub   bool
}

type runner struct {
	opts        options
	pal         palette
	stdout      io.Writer
	stderr      io.Writer
	client      *http.Client
	tracer      *otel.Tracer
	rootSpan    *otel.Span
	authFn      func() (string, error)
	scrubFn     func(string) (string, bool)
	suppressHit bool
	nowFn       func() time.Time
}

// Run executes the zdots-o2-query applet and returns an exit code.
func Run(args []string) int {
	return runWithIO(args, os.Stdout, os.Stderr, isCharDevice(os.Stdout), keychainAuth, execPhiScrub, time.Now)
}

func isCharDevice(f *os.File) bool {
	if f == nil {
		return false
	}
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

func runWithIO(
	args []string,
	stdout, stderr io.Writer,
	tty bool,
	authFn func() (string, error),
	scrubFn func(string) (string, bool),
	nowFn func() time.Time,
) int {
	if len(args) == 0 {
		printUsage(stdout)
		return 0
	}

	opts := options{
		endpoint:  envOr("ZDOTS_O2_ENDPOINT", "http://127.0.0.1:5080"),
		org:       envOr("ZDOTS_O2_ORG", "default"),
		stream:    envOr("ZDOTS_O2_STREAM", "default"),
		rootEmail: envOr("ZDOTS_O2_ROOT_EMAIL", "root@zdots.local"),
		since:     "1h",
		limit:     20,
		ms:        100,
		sqlType:   "logs",
	}

	var pos []string
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--since":
			i++
			if i >= len(args) {
				fmt.Fprintln(stderr, "zdots-o2-query: --since requires a value")
				return 1
			}
			opts.since = args[i]
		case "-n", "--limit":
			i++
			if i >= len(args) {
				fmt.Fprintln(stderr, "zdots-o2-query: --limit requires a value")
				return 1
			}
			n, err := strconv.Atoi(args[i])
			if err != nil || n < 0 {
				fmt.Fprintf(stderr, "zdots-o2-query: invalid --limit: %s\n", args[i])
				return 1
			}
			opts.limit = n
		case "--ms":
			i++
			if i >= len(args) {
				fmt.Fprintln(stderr, "zdots-o2-query: --ms requires a value")
				return 1
			}
			n, err := strconv.ParseInt(args[i], 10, 64)
			if err != nil || n < 0 {
				fmt.Fprintf(stderr, "zdots-o2-query: invalid --ms: %s\n", args[i])
				return 1
			}
			opts.ms = n
		case "--grep":
			i++
			if i >= len(args) {
				fmt.Fprintln(stderr, "zdots-o2-query: --grep requires a value")
				return 1
			}
			opts.grep = args[i]
		case "--type":
			i++
			if i >= len(args) {
				fmt.Fprintln(stderr, "zdots-o2-query: --type requires a value")
				return 1
			}
			opts.sqlType = args[i]
		case "--json":
			opts.jsonOut = true
		case "--no-scrub":
			opts.noScrub = true
		case "-h", "--help":
			printUsage(stdout)
			return 0
		case "--":
			pos = append(pos, args[i+1:]...)
			i = len(args)
		default:
			if strings.HasPrefix(arg, "-") {
				fmt.Fprintf(stderr, "zdots-o2-query: unknown flag: %s\n", arg)
				return 1
			}
			pos = append(pos, arg)
		}
	}

	sub := ""
	subArg := ""
	if len(pos) > 0 {
		sub = pos[0]
	}
	if len(pos) > 1 {
		subArg = pos[1]
	}

	if sub == "" || sub == "help" || sub == "-h" || sub == "--help" {
		printUsage(stdout)
		return 0
	}

	pal := newPalette(tty)
	if opts.noScrub {
		fmt.Fprintf(stderr, "%szdots-o2-query: --no-scrub: defense-in-depth scrub disabled%s\n", pal.dim, pal.rst)
	}

	tracer := otel.New("zdots-o2-query")
	defer tracer.Flush(250 * time.Millisecond)

	root := tracer.Start("o2query.run", nil)
	root.SetAttr("subcommand", sub)
	root.SetAttr("since", opts.since)
	root.SetAttr("limit", opts.limit)
	root.SetAttr("json", opts.jsonOut)

	r := &runner{
		opts:     opts,
		pal:      pal,
		stdout:   stdout,
		stderr:   stderr,
		client:   &http.Client{Timeout: 15 * time.Second},
		tracer:   tracer,
		rootSpan: root,
		authFn:   authFn,
		scrubFn:  scrubFn,
		nowFn:    nowFn,
	}

	var err error
	switch sub {
	case "errors":
		err = r.cmdErrors()
	case "slow":
		err = r.cmdSlow()
	case "failures":
		err = r.cmdFailures()
	case "service":
		err = r.cmdService()
	case "logs":
		err = r.cmdLogs()
	case "trace":
		err = r.cmdTrace(subArg)
	case "sql":
		err = r.cmdSQL(subArg)
	case "streams":
		err = r.cmdStreams()
	default:
		err = fmt.Errorf("unknown subcommand: %s (try -h)", sub)
	}

	if err != nil {
		root.End(false, err.Error())
		fmt.Fprintf(stderr, "zdots-o2-query: %v\n", err)
		return 1
	}
	root.End(true, "")
	return 0
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func printUsage(w io.Writer) {
	fmt.Fprint(w, `bin/zdots-o2-query — read runtime insight back from OpenObserve into a session.

The other half of the feedback loop (Z-135): telemetry is scrubbed at the
INGEST edge (etc/otel-collector.generated.yaml, compiled from etc/phi-patterns.yaml),
so what lands in O2 is already clean. This tool reads it back — recent errors,
slow spans, failures, per-service activity, a single trace — as compact tables
or JSON an agent can reason over. A light phi_scrub pass is kept purely as
defense-in-depth; if it ever trips a suppress-flagged value, that signals an
ingest scrub gap, not normal operation.

Read-only. Local only (loopback O2). Credentials come from the Keychain, never
the command line — safe on the work machine.

Usage:
  zdots-o2-query errors   [--since 1h] [-n 20]          recent ERROR/FATAL logs
  zdots-o2-query slow     [--since 1h] [--ms 100] [-n]  slowest spans over --ms
  zdots-o2-query failures [--since 1h] [-n 20]          error-status spans
  zdots-o2-query service  [--since 1h]                  activity by service/severity
  zdots-o2-query logs     [--since 1h] [--grep STR] [-n] general log search
  zdots-o2-query trace    <TRACE_ID>                    all spans + logs for a trace
  zdots-o2-query sql --type logs|traces "SELECT ..." [--since 1h]   read-only escape hatch
  zdots-o2-query streams                               list O2 streams

Global flags: --since DUR (30s|15m|2h|1d, default 1h) · -n/--limit N (default 20)
              --json (machine-readable) · --no-scrub (skip defense-in-depth) · -h
`)
}

func parseDurationSeconds(d string) (int64, error) {
	if d == "" {
		return 0, fmt.Errorf("bad --since: empty (use 30s|15m|2h|1d)")
	}
	mult := int64(1)
	numPart := d
	switch {
	case strings.HasSuffix(d, "s"):
		numPart = strings.TrimSuffix(d, "s")
	case strings.HasSuffix(d, "m"):
		mult = 60
		numPart = strings.TrimSuffix(d, "m")
	case strings.HasSuffix(d, "h"):
		mult = 3600
		numPart = strings.TrimSuffix(d, "h")
	case strings.HasSuffix(d, "d"):
		mult = 86400
		numPart = strings.TrimSuffix(d, "d")
	}
	n, err := strconv.ParseInt(numPart, 10, 64)
	if err != nil || n < 0 {
		return 0, fmt.Errorf("bad --since: %s (use 30s|15m|2h|1d)", d)
	}
	return n * mult, nil
}

func keychainAuth() (string, error) {
	cmd := exec.Command("/usr/bin/security", "find-generic-password", "-s", "zdots", "-a", "ZDOTS_O2_ROOT_PASSWORD", "-w")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("no O2 password in Keychain (zdots/ZDOTS_O2_ROOT_PASSWORD) — is OpenObserve provisioned? (openobserve-ctl creds)")
	}
	pw := strings.TrimRight(string(out), "\r\n")
	if pw == "" {
		return "", fmt.Errorf("no O2 password in Keychain (zdots/ZDOTS_O2_ROOT_PASSWORD) — is OpenObserve provisioned? (openobserve-ctl creds)")
	}
	return pw, nil
}

func execPhiScrub(input string) (string, bool) {
	bin, err := exec.LookPath("zdots-phi-scrub")
	if err != nil {
		zdotDir := envOr("ZDOTDIR", filepath.Join(os.Getenv("HOME"), ".config", "zsh"))
		candidate := filepath.Join(zdotDir, "bin", "zdots-phi-scrub")
		if _, statErr := os.Stat(candidate); statErr == nil {
			bin = candidate
		} else {
			return input, true
		}
	}
	cmd := exec.Command(bin)
	cmd.Stdin = strings.NewReader(input)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return "", false
	}
	return out.String(), true
}

func (r *runner) basicAuthHeader() (string, error) {
	pw, err := r.authFn()
	if err != nil {
		return "", err
	}
	token := base64.StdEncoding.EncodeToString([]byte(r.opts.rootEmail + ":" + pw))
	return "Basic " + token, nil
}

func (r *runner) apiBase() string {
	return strings.TrimRight(r.opts.endpoint, "/") + "/api/" + r.opts.org
}

type searchResponse struct {
	Hits []map[string]any `json:"hits"`
}

func (r *runner) search(searchType, sql string) ([]map[string]any, error) {
	span := r.tracer.Start("o2query.search", r.rootSpan)
	span.SetAttr("search_type", searchType)

	durSec, err := parseDurationSeconds(r.opts.since)
	if err != nil {
		span.End(false, err.Error())
		return nil, err
	}
	auth, err := r.basicAuthHeader()
	if err != nil {
		span.End(false, err.Error())
		return nil, err
	}

	nowSec := r.nowFn().Unix()
	startUs := (nowSec - durSec) * 1000000
	endUs := (nowSec + 120) * 1000000

	reqBody, err := json.Marshal(map[string]any{
		"query": map[string]any{
			"sql":        sql,
			"start_time": startUs,
			"end_time":   endUs,
			"size":       r.opts.limit,
		},
	})
	if err != nil {
		span.End(false, err.Error())
		return nil, err
	}

	req, err := http.NewRequest(http.MethodPost, r.apiBase()+"/_search?type="+searchType, bytes.NewReader(reqBody))
	if err != nil {
		span.End(false, err.Error())
		return nil, err
	}
	req.Header.Set("Authorization", auth)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.client.Do(req)
	if err != nil {
		span.End(false, err.Error())
		return nil, err
	}
	defer resp.Body.Close()

	span.SetAttr("http_status", resp.StatusCode)
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		span.End(false, err.Error())
		return nil, err
	}

	var parsed searchResponse
	if err := json.Unmarshal(bodyBytes, &parsed); err != nil {
		span.End(false, err.Error())
		return nil, fmt.Errorf("invalid JSON response from O2: %w", err)
	}
	span.SetAttr("hit_count", len(parsed.Hits))
	span.End(true, "")
	return parsed.Hits, nil
}

func (r *runner) scrubField(v string) string {
	if r.opts.noScrub || r.scrubFn == nil || v == "" {
		return v
	}
	out, ok := r.scrubFn(v)
	if !ok {
		r.suppressHit = true
		return "[REDACTED-CONN]"
	}
	return out
}

func (r *runner) warnSuppress() {
	if r.suppressHit {
		fmt.Fprintf(r.stderr, "%szdots-o2-query: ⚠ a suppress-flagged value (conn string) was present in O2 — ingest scrub gap, see Z-135%s\n", r.pal.yel, r.pal.rst)
	}
}

func (r *runner) emitJSON(rows []map[string]any) error {
	if rows == nil {
		rows = []map[string]any{}
	}
	raw, err := json.Marshal(rows)
	if err != nil {
		return err
	}
	doc := string(raw)
	if r.opts.noScrub || r.scrubFn == nil {
		fmt.Fprintln(r.stdout, doc)
		return nil
	}
	out, ok := r.scrubFn(doc)
	if ok {
		fmt.Fprintln(r.stdout, out)
		return nil
	}
	r.suppressHit = true
	sanitized := make([]map[string]any, len(rows))
	for i, row := range rows {
		cp := make(map[string]any, len(row))
		for k, v := range row {
			cp[k] = v
		}
		cp["body"] = nil
		cp["message"] = nil
		cp["status_message"] = nil
		sanitized[i] = cp
	}
	b, _ := json.Marshal(sanitized)
	fmt.Fprintln(r.stdout, string(b))
	return nil
}

func trunc(s string, n int) string {
	runes := []rune(s)
	if len(runes) > n && n > 1 {
		return string(runes[:n-1]) + "…"
	}
	return s
}

func fmtTimestamp(v any) string {
	us := toInt64(v)
	if us == 0 {
		return "?"
	}
	return time.Unix(us/1000000, 0).Format("01-02 15:04:05")
}

func toStr(m map[string]any, key, def string) string {
	v, ok := m[key]
	if !ok || v == nil {
		return def
	}
	switch t := v.(type) {
	case string:
		if t == "" {
			return def
		}
		return t
	case float64:
		if t == float64(int64(t)) {
			return strconv.FormatInt(int64(t), 10)
		}
		return strconv.FormatFloat(t, 'f', -1, 64)
	case int64:
		return strconv.FormatInt(t, 10)
	case int:
		return strconv.Itoa(t)
	default:
		return fmt.Sprint(t)
	}
}

func toInt64(v any) int64 {
	switch t := v.(type) {
	case float64:
		return int64(t)
	case int64:
		return t
	case int:
		return int64(t)
	case json.Number:
		n, _ := t.Int64()
		return n
	case string:
		n, _ := strconv.ParseInt(t, 10, 64)
		return n
	default:
		return 0
	}
}

func toFloat64(v any) float64 {
	switch t := v.(type) {
	case float64:
		return t
	case int64:
		return float64(t)
	case int:
		return float64(t)
	case string:
		f, _ := strconv.ParseFloat(t, 64)
		return f
	default:
		return 0
	}
}

func prefix12(s string) string {
	if len(s) > 12 {
		return s[:12]
	}
	return s
}

func oneLine(s string) string {
	return strings.ReplaceAll(s, "\n", " ")
}

func (r *runner) cmdErrors() error {
	sql := fmt.Sprintf(`SELECT _timestamp, severity, service_name, body, trace_id FROM "%s" WHERE severity IN ('ERROR','FATAL','Error','Fatal') ORDER BY _timestamp DESC`, r.opts.stream)
	hits, err := r.search("logs", sql)
	if err != nil {
		return err
	}
	if r.opts.jsonOut {
		rows := make([]map[string]any, 0, len(hits))
		for _, h := range hits {
			rows = append(rows, map[string]any{
				"ts":       h["_timestamp"],
				"severity": h["severity"],
				"service":  h["service_name"],
				"body":     h["body"],
				"trace_id": h["trace_id"],
			})
		}
		if err := r.emitJSON(rows); err != nil {
			return err
		}
		r.warnSuppress()
		return nil
	}
	fmt.Fprintf(r.stdout, "%s%-14s %-6s %-16s %-50s %s%s\n", r.pal.bold, "TIME", "SEV", "SERVICE", "MESSAGE", "TRACE", r.pal.rst)
	for _, h := range hits {
		ts := fmtTimestamp(h["_timestamp"])
		sev := toStr(h, "severity", "?")
		svc := toStr(h, "service_name", "?")
		body := oneLine(toStr(h, "body", ""))
		tid := toStr(h, "trace_id", "")
		fmt.Fprintf(r.stdout, "%-14s %s%-6s%s %-16s %-50s %s%s%s\n",
			ts, r.pal.red, trunc(sev, 6), r.pal.rst,
			trunc(svc, 16), trunc(r.scrubField(body), 50), r.pal.dim, prefix12(tid), r.pal.rst)
	}
	r.warnSuppress()
	return nil
}

func (r *runner) cmdSlow() error {
	us := r.opts.ms * 1000
	sql := fmt.Sprintf(`SELECT _timestamp, duration, service_name, operation_name, span_status, trace_id FROM "%s" WHERE duration >= %d ORDER BY duration DESC`, r.opts.stream, us)
	hits, err := r.search("traces", sql)
	if err != nil {
		return err
	}
	if r.opts.jsonOut {
		rows := make([]map[string]any, 0, len(hits))
		for _, h := range hits {
			rows = append(rows, map[string]any{
				"ts":          h["_timestamp"],
				"duration_ms": toFloat64(h["duration"]) / 1000.0,
				"service":     h["service_name"],
				"op":          h["operation_name"],
				"status":      h["span_status"],
				"trace_id":    h["trace_id"],
			})
		}
		if err := r.emitJSON(rows); err != nil {
			return err
		}
		r.warnSuppress()
		return nil
	}
	fmt.Fprintf(r.stdout, "%s%-14s %9s %-16s %-34s %-8s %s%s\n", r.pal.bold, "TIME", "DUR(ms)", "SERVICE", "OPERATION", "STATUS", "TRACE", r.pal.rst)
	for _, h := range hits {
		ts := fmtTimestamp(h["_timestamp"])
		dur := strconv.FormatFloat(toFloat64(h["duration"])/1000.0, 'f', -1, 64)
		svc := toStr(h, "service_name", "?")
		op := toStr(h, "operation_name", "?")
		st := toStr(h, "span_status", "?")
		tid := toStr(h, "trace_id", "")
		c := r.pal.rst
		if st == "ERROR" {
			c = r.pal.red
		}
		fmt.Fprintf(r.stdout, "%-14s %9s %-16s %-34s %s%-8s%s %s%s%s\n",
			ts, dur, trunc(svc, 16), trunc(r.scrubField(op), 34), c, trunc(st, 8), r.pal.rst, r.pal.dim, prefix12(tid), r.pal.rst)
	}
	r.warnSuppress()
	return nil
}

func (r *runner) cmdFailures() error {
	sql := fmt.Sprintf(`SELECT _timestamp, service_name, operation_name, status_message, trace_id FROM "%s" WHERE span_status = 'ERROR' OR status_code = 2 ORDER BY _timestamp DESC`, r.opts.stream)
	hits, err := r.search("traces", sql)
	if err != nil {
		return err
	}
	if r.opts.jsonOut {
		rows := make([]map[string]any, 0, len(hits))
		for _, h := range hits {
			rows = append(rows, map[string]any{
				"ts":             h["_timestamp"],
				"service":        h["service_name"],
				"op":             h["operation_name"],
				"status_message": h["status_message"],
				"trace_id":       h["trace_id"],
			})
		}
		if err := r.emitJSON(rows); err != nil {
			return err
		}
		r.warnSuppress()
		return nil
	}
	fmt.Fprintf(r.stdout, "%s%-14s %-16s %-30s %-30s %s%s\n", r.pal.bold, "TIME", "SERVICE", "OPERATION", "MESSAGE", "TRACE", r.pal.rst)
	for _, h := range hits {
		ts := fmtTimestamp(h["_timestamp"])
		svc := toStr(h, "service_name", "?")
		op := toStr(h, "operation_name", "?")
		msg := oneLine(toStr(h, "status_message", ""))
		tid := toStr(h, "trace_id", "")
		fmt.Fprintf(r.stdout, "%-14s %-16s %-30s %s%-30s%s %s%s%s\n",
			ts, trunc(svc, 16), trunc(r.scrubField(op), 30), r.pal.red, trunc(r.scrubField(msg), 30), r.pal.rst, r.pal.dim, prefix12(tid), r.pal.rst)
	}
	r.warnSuppress()
	return nil
}

func (r *runner) cmdService() error {
	sql := fmt.Sprintf(`SELECT service_name, severity, count(*) AS n FROM "%s" GROUP BY service_name, severity ORDER BY n DESC`, r.opts.stream)
	r.opts.limit = 200
	hits, err := r.search("logs", sql)
	if err != nil {
		return err
	}
	if r.opts.jsonOut {
		rows := make([]map[string]any, 0, len(hits))
		for _, h := range hits {
			rows = append(rows, map[string]any{
				"service":  h["service_name"],
				"severity": h["severity"],
				"count":    h["n"],
			})
		}
		return r.emitJSON(rows)
	}
	fmt.Fprintf(r.stdout, "%s%-22s %-8s %8s%s\n", r.pal.bold, "SERVICE", "SEVERITY", "COUNT", r.pal.rst)
	for _, h := range hits {
		svc := toStr(h, "service_name", "?")
		sev := toStr(h, "severity", "?")
		n := toStr(h, "n", "0")
		c := r.pal.rst
		switch sev {
		case "ERROR", "FATAL", "Error", "Fatal":
			c = r.pal.red
		case "WARN", "Warn":
			c = r.pal.yel
		}
		fmt.Fprintf(r.stdout, "%-22s %s%-8s%s %8s\n", trunc(svc, 22), c, trunc(sev, 8), r.pal.rst, n)
	}
	return nil
}

func (r *runner) cmdLogs() error {
	where := "1=1"
	if r.opts.grep != "" {
		escaped := strings.ReplaceAll(r.opts.grep, "'", "''")
		where = fmt.Sprintf("str_match(body, '%s')", escaped)
	}
	sql := fmt.Sprintf(`SELECT _timestamp, severity, service_name, body, trace_id FROM "%s" WHERE %s ORDER BY _timestamp DESC`, r.opts.stream, where)
	hits, err := r.search("logs", sql)
	if err != nil {
		return err
	}
	if r.opts.jsonOut {
		rows := make([]map[string]any, 0, len(hits))
		for _, h := range hits {
			rows = append(rows, map[string]any{
				"ts":       h["_timestamp"],
				"severity": h["severity"],
				"service":  h["service_name"],
				"body":     h["body"],
				"trace_id": h["trace_id"],
			})
		}
		if err := r.emitJSON(rows); err != nil {
			return err
		}
		r.warnSuppress()
		return nil
	}
	fmt.Fprintf(r.stdout, "%s%-14s %-6s %-16s %-54s %s%s\n", r.pal.bold, "TIME", "SEV", "SERVICE", "MESSAGE", "TRACE", r.pal.rst)
	for _, h := range hits {
		ts := fmtTimestamp(h["_timestamp"])
		sev := toStr(h, "severity", "?")
		svc := toStr(h, "service_name", "?")
		body := oneLine(toStr(h, "body", ""))
		tid := toStr(h, "trace_id", "")
		fmt.Fprintf(r.stdout, "%-14s %-6s %-16s %-54s %s%s%s\n",
			ts, trunc(sev, 6), trunc(svc, 16), trunc(r.scrubField(body), 54), r.pal.dim, prefix12(tid), r.pal.rst)
	}
	r.warnSuppress()
	return nil
}

func (r *runner) cmdTrace(tid string) error {
	if tid == "" {
		return fmt.Errorf("trace needs a TRACE_ID")
	}
	if r.opts.since == "1h" {
		r.opts.since = "7d"
	}
	r.opts.limit = 500
	escapedTid := strings.ReplaceAll(tid, "'", "''")

	fmt.Fprintf(r.stdout, "%s── spans%s  %strace %s%s\n", r.pal.bold, r.pal.rst, r.pal.dim, tid, r.pal.rst)
	spans, err := r.search("traces", fmt.Sprintf(`SELECT start_time, duration, operation_name, span_status, service_name FROM "%s" WHERE trace_id = '%s' ORDER BY start_time`, r.opts.stream, escapedTid))
	if err != nil {
		return err
	}
	for _, h := range spans {
		dur := strconv.FormatFloat(toFloat64(h["duration"])/1000.0, 'f', -1, 64)
		svc := toStr(h, "service_name", "?")
		op := toStr(h, "operation_name", "?")
		st := toStr(h, "span_status", "?")
		c := r.pal.rst
		if st == "ERROR" {
			c = r.pal.red
		}
		fmt.Fprintf(r.stdout, "  %9sms  %-16s %s%-32s%s %s\n", dur, trunc(svc, 16), c, trunc(r.scrubField(op), 32), r.pal.rst, st)
	}

	fmt.Fprintf(r.stdout, "\n%s── logs%s\n", r.pal.bold, r.pal.rst)
	logs, err := r.search("logs", fmt.Sprintf(`SELECT _timestamp, severity, body FROM "%s" WHERE trace_id = '%s' ORDER BY _timestamp`, r.opts.stream, escapedTid))
	if err != nil {
		return err
	}
	for _, h := range logs {
		ts := fmtTimestamp(h["_timestamp"])
		sev := toStr(h, "severity", "?")
		body := oneLine(toStr(h, "body", ""))
		fmt.Fprintf(r.stdout, "  %-14s %-6s %s\n", ts, sev, trunc(r.scrubField(body), 80))
	}
	r.warnSuppress()
	return nil
}

func (r *runner) cmdSQL(q string) error {
	if q == "" {
		return fmt.Errorf("sql needs a query string")
	}
	if !selectRe.MatchString(q) {
		return fmt.Errorf("only SELECT queries allowed (read-only)")
	}
	if strings.Contains(q, ";") {
		return fmt.Errorf("';' not allowed in query")
	}
	hits, err := r.search(r.opts.sqlType, q)
	if err != nil {
		return err
	}
	if r.opts.jsonOut {
		if err := r.emitJSON(hits); err != nil {
			return err
		}
		r.warnSuppress()
		return nil
	}
	if hits == nil {
		hits = []map[string]any{}
	}
	b, err := json.MarshalIndent(hits, "", "  ")
	if err != nil {
		return err
	}
	fmt.Fprintln(r.stdout, string(b))
	r.warnSuppress()
	return nil
}

func (r *runner) cmdStreams() error {
	auth, err := r.basicAuthHeader()
	if err != nil {
		return err
	}
	for _, t := range []string{"logs", "traces", "metrics"} {
		span := r.tracer.Start("o2query.streams", r.rootSpan)
		span.SetAttr("stream_type", t)
		fmt.Fprintf(r.stdout, "%s%-8s%s ", r.pal.bold, t, r.pal.rst)

		req, reqErr := http.NewRequest(http.MethodGet, r.apiBase()+"/streams?type="+t, nil)
		if reqErr != nil {
			span.End(false, reqErr.Error())
			fmt.Fprintln(r.stdout, "?")
			continue
		}
		req.Header.Set("Authorization", auth)
		resp, doErr := r.client.Do(req)
		if doErr != nil {
			span.End(false, doErr.Error())
			fmt.Fprintln(r.stdout, "?")
			continue
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var res struct {
			List []struct {
				Name string `json:"name"`
			} `json:"list"`
		}
		if json.Unmarshal(body, &res) != nil {
			span.End(false, "invalid json")
			fmt.Fprintln(r.stdout, "?")
			continue
		}
		names := make([]string, 0, len(res.List))
		for _, item := range res.List {
			names = append(names, item.Name)
		}
		span.SetAttr("stream_count", len(names))
		span.End(true, "")
		fmt.Fprintln(r.stdout, strings.Join(names, ", "))
	}
	return nil
}
