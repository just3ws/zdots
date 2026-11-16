package zsvc

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

func usage() string {
	return `Usage: zsvc <command> [service] [options]

Unified service control for zdots-managed services.

COMMANDS
  list                  Table of all services: state, pid, endpoint
  start   <service>     Start a service
  stop    <service>     Stop a service
  restart <service>     Restart a service (stop + start if no native restart)
  wait    <service> [--timeout N]  Block until the service is healthy (default 30s)
  reload  <service>     Graceful zero-downtime reload (nginx)
  status  <service>     Full status from the service's ctl script
  health  [--json] [service|all] Probe service liveness and local URLs
  map     [--json] [service]     "You are here": purpose, API kind, auth,
                                  a runnable example, and dependencies — for
                                  external tools/AI discovering what to call
  logs    <service>     Tail the service log (Ctrl+C to stop)
  logs    all [--paths|--json] [options] Tail all registered service logs
  diag    <service>     Status + health + launchd state + last 50 log lines
  validate <service>    Validate service config (llama, otel)

SERVICES
  llama     llama-server   — AI inference        port 11500  [aliases: ai, server]
  embed     llama-embed    — Embedding server    port 11501  [aliases: llama-embed]
  otel      otel-collector — Telemetry           port 4318   [aliases: telemetry]
  colima    Colima VM      — Docker runtime                  [aliases: vm, docker]
  nginx     nginx          — TLS reverse proxy   80/443      [aliases: web, proxy]
  postgres  postgresql@V   — ` + "`my`" + ` database       port 5432   [aliases: pg, db]
  redis     redis          — analytics cache     port 6379   [aliases: cache, kv]
  worker    zdots-worker   — async job queue drain            [aliases: jobs]

NOTE
  V is ZDOTS_POSTGRES_VERSION (default 18); ` + "`zsvc list`" + ` shows the resolved name.
  nginx is a root (system-domain) LaunchDaemon and uses sudo via nginx-ctl.
  postgres/redis are user LaunchAgents managed directly via launchctl.
  zsvc verifies registration and component health. For branch readiness, run:
    zdots-ctl status && bats tests/platform_e2e.bats

EXAMPLES
  zsvc list
  zsvc start llama
  zsvc restart otel
  zsvc restart llama && zsvc wait llama   # restart, then block until healthy
  zsvc logs embed
  zsvc logs all --paths
  zsvc logs all -n 100
  zsvc health
  zsvc map                   # discovery card for every service (name/purpose/auth/example)
  zsvc map llama --json      # one service, machine-readable, for an external AI/tool
  zsvc status postgres
  zsvc reload nginx          # graceful config reload (after editing servers/*.conf)
  zsvc diag llama
  zsvc status llama --json

NOTES
  zsvc controls individual services. For the full platform stack use zdots-ctl:
    zdots-ctl up      start everything in dependency order
    zdots-ctl down    stop everything
    zdots-ctl check   deep health diagnostic
  Lifecycle diagrams: docs/platform-service-plane.md
  Full command index (all bin/, not just services): agent-guide, agent-guide --json
`
}

type svcDesc struct {
	Name         string
	Display      string
	Label        string
	Log          string
	Ctl          string
	Endpoint     string
	Type         string
	Managed      bool
	Aliases      []string
	Install      string
	Start        string
	Stop         string
	Restart      string
	Status       string
	Health       string
	Logs         string
	Validate     string
	HealthPolicy string
	Detail       string
	// Map metadata
	Purpose    string
	APIKind    string
	Auth       string
	HealthPath string
	Example    string
	DependsOn  []string
	Docs       string
}

type envCtx struct {
	home      string
	zdotdir   string
	binDir    string
	stateDir  string
	brewPfx   string
	uid       string
	redisHost string
	redisPort string
	services  []svcDesc
}

func loadCtx(zdotdirOverride string) envCtx {
	home, _ := os.UserHomeDir()
	zdotdir := zdotdirOverride
	if zdotdir == "" {
		zdotdir = envOr("ZDOTDIR", filepath.Join(home, ".config", "zsh"))
	}
	binDir := filepath.Join(zdotdir, "bin")
	xdgState := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	state := filepath.Join(xdgState, "zsh")
	brew := envOr("HOMEBREW_PREFIX", "/opt/homebrew")
	pgVer := envOr("ZDOTS_POSTGRES_VERSION", "18")

	aiHost := bracketIPv6(envOr("ZDOTS_AI_HOST", "127.0.0.1"))
	embedHost := bracketIPv6(envOr("ZDOTS_AI_EMBED_HOST", "127.0.0.1"))
	otelHost := bracketIPv6(envOr("ZDOTS_OTEL_HOST", "127.0.0.1"))
	jaegerHost := bracketIPv6(envOr("ZDOTS_JAEGER_HOST", "127.0.0.1"))
	o2Host := bracketIPv6(envOr("ZDOTS_O2_HOST", "127.0.0.1"))
	stHost := bracketIPv6(envOr("ZDOTS_STATUS_HOST", "127.0.0.1"))
	gsHost := bracketIPv6(envOr("ZDOTS_GEMSTASH_HOST", "127.0.0.1"))
	rdHost := bracketIPv6(envOr("ZDOTS_REDIS_HOST", "127.0.0.1"))
	gsPort := envOr("ZDOTS_GEMSTASH_PORT", "9292")

	svcs := []svcDesc{
		{
			Name: "llama", Display: "llama-server", Label: "com.zdots.llama-server",
			Log: filepath.Join(state, "llama-server.log"), Ctl: "llama-ctl",
			Endpoint: envOr("ZDOTS_AI_ENDPOINT", fmt.Sprintf("http://%s:%s", aiHost, envOr("ZDOTS_AI_PORT", "11500"))),
			Type:     "launchd", Managed: true, Aliases: []string{"llama-server", "ai", "server"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs", Validate: "validate",
			HealthPolicy: "required", Detail: "/health",
			Purpose: "OpenAI-compatible chat completions, local inference only", APIKind: "openai-chat", Auth: "none (loopback-trusted)",
			HealthPath: "/health", Example: `curl -s http://127.0.0.1:11500/v1/chat/completions -d '{"model":"local","messages":[{"role":"user","content":"hi"}]}'`,
			Docs: "docs/llama-cpp.md",
		},
		{
			Name: "embed", Display: "llama-embed", Label: "com.zdots.llama-embed",
			Log: filepath.Join(state, "llama-embed.log"), Ctl: "llama-ctl",
			Endpoint: envOr("ZDOTS_AI_EMBED_ENDPOINT", fmt.Sprintf("http://%s:%s", embedHost, envOr("ZDOTS_AI_EMBED_PORT", "11501"))),
			Type:     "launchd", Managed: true, Aliases: []string{"llama-embed", "embedding"},
			Install: "install-embed", Start: "start-embed", Stop: "stop-embed", Restart: "restart-embed", Status: "status-embed", Health: "status-embed",
			HealthPolicy: "registered", Detail: "/health",
			Purpose: "Text embeddings for vector search", APIKind: "openai-embeddings", Auth: "none (loopback-trusted)",
			HealthPath: "/health", Example: `curl -s http://127.0.0.1:11501/v1/embeddings -d '{"model":"local","input":"hi"}'`,
			Docs: "docs/llama-cpp.md",
		},
		{
			Name: "otel", Display: "otel-collector", Label: "com.zdots.otel-collector",
			Log: filepath.Join(state, "otel-collector.log"), Ctl: "otel-collector",
			Endpoint: envOr("ZDOTS_OTLP_ENDPOINT", fmt.Sprintf("http://%s:%s", otelHost, envOr("ZDOTS_OTEL_HTTP_PORT", "4318"))),
			Type:     "launchd", Managed: true, Aliases: []string{"otel-collector", "telemetry", "collector"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs", Validate: "validate",
			HealthPolicy: "registered", Detail: "OTLP receiver",
			Purpose: "OTLP ingestion for traces/metrics/logs", APIKind: "otlp-http", Auth: "none (loopback-trusted)",
			HealthPath: "(health subcommand)", Example: `curl -s -H 'Content-Type: application/json' http://127.0.0.1:4318/v1/traces -d '{"resourceSpans":[]}'`,
			Docs: "docs/otel-collector-guide.md",
		},
		{
			Name: "jaeger", Display: "jaeger", Label: "com.zdots.jaeger",
			Log: filepath.Join(state, "jaeger.log"), Ctl: "jaeger-ctl",
			Endpoint: envOr("ZDOTS_JAEGER_ENDPOINT", fmt.Sprintf("http://%s:%s", jaegerHost, envOr("ZDOTS_JAEGER_UI_PORT", "16686"))),
			Type:     "launchd", Managed: true, Aliases: []string{"tracing", "trace-ui"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs", Validate: "validate",
			HealthPolicy: "registered", Detail: "Jaeger UI",
			Purpose:    "Distributed trace storage and query UI", APIKind: "http", Auth: "none (loopback-trusted)",
			HealthPath: "/", Example: "curl -s http://127.0.0.1:16686/api/services", DependsOn: []string{"otel"},
			Docs:       "docs/otel-collector-guide.md",
		},
		{
			Name: "o2", Display: "openobserve", Label: "com.zdots.openobserve",
			Log: filepath.Join(state, "openobserve.log"), Ctl: "openobserve-ctl",
			Endpoint: envOr("ZDOTS_O2_ENDPOINT", fmt.Sprintf("http://%s:%s", o2Host, envOr("ZDOTS_O2_PORT", "5080"))),
			Type:     "launchd", Managed: true, Aliases: []string{"openobserve", "observability", "obs", "telemetry-ui"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs",
			HealthPolicy: "registered",
			Purpose:      "Trace/log/metric storage and query UI", APIKind: "http+sql", Auth: "root creds via openobserve-ctl creds",
			HealthPath: "/healthz", Example: "curl -s http://127.0.0.1:5080/healthz", DependsOn: []string{"otel"},
			Docs: "docs/openobserve.md",
		},
		{
			Name: "colima", Display: "colima", Label: "com.zdots.colima-autostart",
			Ctl: "colima", Type: "colima", Managed: true, Aliases: []string{"vm", "docker"},
			Start: "start", Stop: "stop", Status: "status", Health: "status", Logs: "logs",
			HealthPolicy: "optional", Detail: "colima status",
			Purpose: "Docker/container runtime VM", APIKind: "docker-socket", Auth: "none (local user)",
			HealthPath: "colima status", Example: `DOCKER_HOST="unix://$(colima-status socket)" docker ps`,
		},
		{
			Name: "nginx", Display: "nginx", Label: brewLabel(home, "nginx"),
			Log: filepath.Join(brew, "var", "log", "nginx", "error.log"), Ctl: "nginx-ctl",
			Endpoint: "https://my.localhost (+ llama/embed/o2/zdots.localhost)",
			Type:     "nginx", Managed: true, Aliases: []string{"web", "proxy"},
			Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs", Validate: "validate",
			HealthPolicy: "registered", Detail: "localhost:80",
			Purpose: "TLS-terminating reverse proxy fronting the .localhost services", APIKind: "https", Auth: "none (loopback-trusted)",
			HealthPath: "/", Example: "curl -sk https://my.localhost/up", DependsOn: []string{"postgres", "redis"},
		},
		{
			Name: "postgres", Display: "postgresql@" + pgVer, Label: brewLabel(home, "postgresql@"+pgVer),
			Log:      filepath.Join(brew, "var", "log", "postgresql@"+pgVer+".log"),
			Endpoint: fmt.Sprintf("postgresql:///my (:%s)", envOr("ZDOTS_PG_PORT", "5432")),
			Type:     "plist", Managed: true, Aliases: []string{"postgresql", "pg", "db", "database"},
			Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status",
			HealthPolicy: "required", Detail: "pg_isready: accepting connections",
			Purpose: "Knowledge-layer store — database 'my'", APIKind: "sql", Auth: "zdots_ro (read) / zdots_rw (write) via scram-sha-256",
			HealthPath: "pg_isready", Example: "psql -U zdots_ro my", Docs: "docs/wiki/AI-and-Knowledge-Layer.md",
		},
		{
			Name: "redis", Display: "redis", Label: brewLabel(home, "redis"),
			Log:      filepath.Join(brew, "var", "log", "redis.log"),
			Endpoint: fmt.Sprintf("%s:%s", rdHost, envOr("ZDOTS_REDIS_PORT", "6379")),
			Type:     "plist", Managed: true, Aliases: []string{"cache", "kv"},
			Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status",
			HealthPolicy: "registered", Detail: "PONG",
			Purpose: "Command-analytics cache buffer", APIKind: "redis", Auth: "none (loopback-trusted)",
			HealthPath: "PING", Example: "redis-cli -h 127.0.0.1 -p 6379 KEYS 'zdots:cmds:*'",
		},
		{
			Name: "worker", Display: "zdots-worker", Label: "com.zdots.worker",
			Log: filepath.Join(state, "zdots-worker.log"), Ctl: "zdots-worker",
			Endpoint: "jobs queue (my)", Type: "launchd", Managed: true, Aliases: []string{"jobs", "brain-worker"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs",
			HealthPolicy: "registered", Detail: "process alive",
			Purpose: "Async job queue drain for Knowledge Layer (my)", APIKind: "process", Auth: "n/a (no network endpoint)",
			HealthPath: "process alive", DependsOn: []string{"postgres"},
		},
		{
			Name: "status", Display: "zdots-statusd", Label: "com.zdots.statusd",
			Log: filepath.Join(state, "zdots-statusd.log"), Ctl: "zdots-statusd-ctl",
			Endpoint: fmt.Sprintf("http://%s:%s", stHost, envOr("ZDOTS_STATUS_PORT", "11600")),
			Type:     "launchd", Managed: true, Aliases: []string{"statusd", "statusd-ctl", "control-plane", "dashboard"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs",
			HealthPolicy: "registered",
			Purpose:      "Control-plane console — service/launchd/log health and LAN System Atlas", APIKind: "http+html", Auth: "none (localhost console; LAN map is read-only)",
			HealthPath: "/healthz", Example: "curl -s http://127.0.0.1:11600/healthz", Docs: "docs/system-atlas.md",
		},
		{
			Name: "gemstash", Display: "gemstash", Label: "com.zdots.gemstash",
			Log: filepath.Join(state, "gemstash.log"), Ctl: "gemstash-ctl",
			Endpoint: fmt.Sprintf("http://%s:%s", gsHost, gsPort),
			Type:     "launchd", Managed: true, Aliases: []string{"gems", "gem-cache", "rubygems", "gem-proxy"},
			Install: "install", Start: "start", Stop: "stop", Restart: "restart", Status: "status", Health: "status", Logs: "logs",
			HealthPolicy: "registered",
			Purpose:      "RubyGems caching proxy + private gem host", APIKind: "http", Auth: "none (loopback-trusted)",
			HealthPath: "/", Example: fmt.Sprintf("curl -s http://127.0.0.1:%s/", gsPort),
		},
	}

	return envCtx{
		home:      home,
		zdotdir:   zdotdir,
		binDir:    binDir,
		stateDir:  state,
		brewPfx:   brew,
		uid:       strconv.Itoa(os.Getuid()),
		redisHost: envOr("ZDOTS_REDIS_HOST", "127.0.0.1"),
		redisPort: envOr("ZDOTS_REDIS_PORT", "6379"),
		services:  svcs,
	}
}

func (c envCtx) resolve(alias string) (svcDesc, bool) {
	for _, s := range c.services {
		if s.Name == alias {
			return s, true
		}
		for _, a := range s.Aliases {
			if a == alias {
				return s, true
			}
		}
	}
	return svcDesc{}, false
}

func (c envCtx) ctlPath(s svcDesc) string {
	if s.Ctl == "" {
		return ""
	}
	cand := filepath.Join(c.binDir, s.Ctl)
	if info, err := os.Stat(cand); err == nil && !info.IsDir() {
		return cand
	}
	return s.Ctl
}

func (c envCtx) mustResolve(alias string) (svcDesc, bool) {
	s, ok := c.resolve(alias)
	if ok {
		return s, true
	}
	var names []string
	for _, x := range c.services {
		names = append(names, x.Name)
	}
	fmt.Fprintf(os.Stderr, "zsvc: unknown service: %s\n", alias)
	fmt.Fprintf(os.Stderr, "zsvc: known services: %s\n", strings.Join(names, ", "))
	return svcDesc{}, false
}

// Run executes the zsvc command and returns the process exit code.
func Run(args []string) int {
	if len(args) == 0 {
		fmt.Fprint(os.Stderr, usage())
		return 1
	}
	cmd := args[0]
	rest := args[1:]
	if cmd == "-h" || cmd == "--help" {
		fmt.Print(usage())
		return 0
	}

	c := loadCtx("")
	tr := otel.New("zsvc")
	sp := tr.Start("zsvc."+cmd, nil)

	var rc int
	switch cmd {
	case "list":
		fmt.Print(listText(c, tr, sp))
		rc = 0
	case "start":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdStart(c, rest[0])
		}
	case "stop":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdStop(c, rest[0])
		}
	case "restart":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdRestart(c, rest[0])
		}
	case "wait":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdWait(c, rest)
		}
	case "reload":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdReload(c, rest[0])
		}
	case "status":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdStatus(c, rest)
		}
	case "health":
		rc = cmdHealth(c, rest, tr, sp)
	case "map":
		rc = cmdMap(c, rest)
	case "logs":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdLogs(c, rest)
		}
	case "diag":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdDiag(c, rest[0])
		}
	case "validate":
		if len(rest) < 1 {
			fmt.Fprint(os.Stderr, usage())
			rc = 1
		} else {
			rc = cmdValidate(c, rest[0])
		}
	default:
		fmt.Fprintf(os.Stderr, "zsvc: unknown command: %s\n", cmd)
		fmt.Fprint(os.Stderr, usage())
		rc = 1
	}

	sp.SetAttr("exit_code", rc)
	sp.End(rc == 0, "")
	tr.Flush(250 * time.Millisecond)
	return rc
}

// ListText returns the formatted `zsvc list` table for in-process callers.
func ListText(zdotdir string) string {
	return listText(loadCtx(zdotdir), nil, nil)
}

func listText(c envCtx, tr *otel.Tracer, parent *otel.Span) string {
	type row struct{ state, pid string }
	rows := make([]row, len(c.services))
	var wg sync.WaitGroup
	for i, s := range c.services {
		wg.Add(1)
		go func(idx int, svc svcDesc) {
			defer wg.Done()
			var sp *otel.Span
			if tr != nil {
				sp = tr.Start("zsvc.state."+svc.Name, parent)
			}
			st, pid := probeState(c, svc)
			rows[idx] = row{st, pid}
			if sp != nil {
				sp.SetAttr("state", st)
				sp.End(true, "")
			}
		}(i, s)
	}
	wg.Wait()

	var buf bytes.Buffer
	fmt.Fprintf(&buf, "%-16s  %-18s  %-8s  %s\n", "SERVICE", "STATE", "PID", "ENDPOINT")
	fmt.Fprintf(&buf, "%-16s  %-18s  %-8s  %s\n", "-------", "-----", "---", "--------")
	for i, s := range c.services {
		ep := s.Endpoint
		if ep == "" {
			ep = "-"
		}
		fmt.Fprintf(&buf, "%-16s  %-18s  %-8s  %s\n", s.Display, rows[i].state, rows[i].pid, ep)
	}
	return buf.String()
}

func cmdMap(c envCtx, args []string) int {
	jsonMode := false
	target := ""
	for _, a := range args {
		if a == "--json" {
			jsonMode = true
		} else {
			target = a
		}
	}

	var svcs []svcDesc
	if target != "" {
		s, ok := c.mustResolve(target)
		if !ok {
			return 1
		}
		svcs = []svcDesc{s}
	} else {
		svcs = c.services
	}

	if jsonMode {
		type mapEntry struct {
			Name       string   `json:"name"`
			Display    string   `json:"display"`
			Endpoint   string   `json:"endpoint"`
			Purpose    string   `json:"purpose"`
			APIKind    string   `json:"api_kind"`
			Auth       string   `json:"auth"`
			HealthPath string   `json:"health_path"`
			Example    string   `json:"example"`
			DependsOn  []string `json:"depends_on"`
			Docs       string   `json:"docs"`
		}
		entries := make([]mapEntry, 0, len(svcs))
		for _, s := range svcs {
			deps := s.DependsOn
			if deps == nil {
				deps = []string{}
			}
			entries = append(entries, mapEntry{
				Name:       s.Name,
				Display:    s.Display,
				Endpoint:   s.Endpoint,
				Purpose:    s.Purpose,
				APIKind:    s.APIKind,
				Auth:       s.Auth,
				HealthPath: s.HealthPath,
				Example:    s.Example,
				DependsOn:  deps,
				Docs:       s.Docs,
			})
		}
		out := struct {
			AgentGuide string     `json:"agent_guide"`
			Services   []mapEntry `json:"services"`
		}{AgentGuide: "agent-guide --json", Services: entries}
		b, _ := json.Marshal(out)
		fmt.Println(string(b))
		return 0
	}

	for _, s := range svcs {
		ep := s.Endpoint
		if ep == "" {
			ep = "-"
		}
		fmt.Printf("%s (%s)\n", s.Display, s.Name)
		fmt.Printf("  endpoint:    %s\n", ep)
		fmt.Printf("  purpose:     %s\n", s.Purpose)
		fmt.Printf("  api kind:    %s\n", s.APIKind)
		fmt.Printf("  auth:        %s\n", s.Auth)
		fmt.Printf("  health:      %s\n", s.HealthPath)
		fmt.Printf("  example:     %s\n", s.Example)
		if len(s.DependsOn) > 0 {
			fmt.Printf("  depends on:  %s\n", strings.Join(s.DependsOn, " "))
		}
		if s.Docs != "" {
			fmt.Printf("  docs:        %s\n", s.Docs)
		}
		fmt.Println()
	}
	fmt.Println("Full platform command index: agent-guide (agent-guide --json for machine-readable)")
	return 0
}

var localURLs = []struct{ name, url string }{
	{"llama.localhost", "https://llama.localhost/health"},
	{"embed.localhost", "https://embed.localhost/health"},
	{"o2.localhost", "https://o2.localhost/healthz"},
	{"zdots.localhost", "https://zdots.localhost/healthz"},
	{"gemstash.localhost", "https://gemstash.localhost/"},
	{"my.localhost", "https://my.localhost/up"},
}

func cmdHealth(c envCtx, args []string, tr *otel.Tracer, parent *otel.Span) int {
	jsonMode := false
	var rest []string
	for _, a := range args {
		if a == "--json" {
			jsonMode = true
		} else {
			rest = append(rest, a)
		}
	}

	if len(rest) == 0 || rest[0] == "all" || rest[0] == "--all" {
		return cmdHealthAll(c, jsonMode, tr, parent)
	}

	s, ok := c.mustResolve(rest[0])
	if !ok {
		return 1
	}
	st, _ := probeState(c, s)
	healthy := probeHealthy(c, s)
	hStr := "fail"
	if healthy {
		hStr = "ok"
	}
	if jsonMode {
		payload := map[string]string{
			"name":     s.Name,
			"display":  s.Display,
			"state":    st,
			"health":   hStr,
			"detail":   s.Detail,
			"endpoint": s.Endpoint,
			"log":      s.Log,
		}
		b, _ := json.Marshal(payload)
		fmt.Println(string(b))
	} else {
		fmt.Printf("%-16s  %-6s  %s\n", s.Display, hStr, s.Detail)
	}
	if healthy {
		return 0
	}
	return 1
}

func cmdHealthAll(c envCtx, jsonMode bool, tr *otel.Tracer, parent *otel.Span) int {
	type svcRes struct {
		Name     string `json:"name"`
		Display  string `json:"display"`
		State    string `json:"state"`
		Health   string `json:"health"`
		Policy   string `json:"policy"`
		Detail   string `json:"detail"`
		Endpoint string `json:"endpoint"`
		Log      string `json:"log"`
	}
	type urlRes struct {
		Name   string `json:"name"`
		URL    string `json:"url"`
		Status string `json:"status"`
		Code   string `json:"code"`
	}

	svcResults := make([]svcRes, len(c.services))
	urlResults := make([]urlRes, len(localURLs))
	ingressReq := false
	for _, s := range c.services {
		if s.Name == "nginx" && s.HealthPolicy == "required" {
			ingressReq = true
		}
	}

	var wg sync.WaitGroup
	for i, s := range c.services {
		wg.Add(1)
		go func(idx int, svc svcDesc) {
			defer wg.Done()
			sp := tr.Start("zsvc.health."+svc.Name, parent)
			st, _ := probeState(c, svc)
			ok := probeHealthy(c, svc)
			h := "fail"
			if ok {
				h = "ok"
			}
			svcResults[idx] = svcRes{
				Name: svc.Name, Display: svc.Display, State: st, Health: h,
				Policy: svc.HealthPolicy, Detail: svc.Detail, Endpoint: svc.Endpoint, Log: svc.Log,
			}
			sp.SetAttr("healthy", ok)
			sp.End(ok, "")
		}(i, s)
	}

	tlsClient := &http.Client{
		Timeout: 2 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}
	for i, u := range localURLs {
		wg.Add(1)
		go func(idx int, target struct{ name, url string }) {
			defer wg.Done()
			code := "000"
			if resp, err := tlsClient.Get(target.url); err == nil {
				code = fmt.Sprintf("%03d", resp.StatusCode)
				_ = resp.Body.Close()
			}
			status := "ok"
			if code == "000" || strings.HasPrefix(code, "5") {
				if ingressReq {
					status = "fail"
				} else {
					status = "skip"
				}
			}
			urlResults[idx] = urlRes{Name: target.name, URL: target.url, Status: status, Code: code}
		}(i, u)
	}
	wg.Wait()

	failed := false
	for _, r := range svcResults {
		if r.Health != "ok" && r.Policy == "required" {
			failed = true
		}
	}
	for _, u := range urlResults {
		if u.Status == "fail" {
			failed = true
		}
	}

	if jsonMode {
		payload := struct {
			Healthy   bool     `json:"healthy"`
			Services  []svcRes `json:"services"`
			LocalURLs []urlRes `json:"local_urls"`
		}{Healthy: !failed, Services: svcResults, LocalURLs: urlResults}
		b, _ := json.Marshal(payload)
		fmt.Println(string(b))
		if failed {
			return 1
		}
		return 0
	}

	fmt.Printf("%-16s  %-18s  %-8s  %-6s  %s\n", "SERVICE", "STATE", "POLICY", "HEALTH", "DETAIL")
	fmt.Printf("%-16s  %-18s  %-8s  %-6s  %s\n", "-------", "-----", "------", "------", "------")
	for _, r := range svcResults {
		fmt.Printf("%-16s  %-18s  %-8s  %-6s  %s\n", r.Display, r.State, r.Policy, r.Health, r.Detail)
	}
	fmt.Println()
	fmt.Printf("%-16s  %-6s  %-5s  %s\n", "LOCAL_URL", "STATUS", "CODE", "URL")
	fmt.Printf("%-16s  %-6s  %-5s  %s\n", "---------", "------", "----", "---")
	for _, u := range urlResults {
		fmt.Printf("%-16s  %-6s  %-5s  %s\n", u.Name, u.Status, u.Code, u.URL)
	}
	if failed {
		return 1
	}
	return 0
}

func cmdStart(c envCtx, target string) int {
	s, ok := c.mustResolve(target)
	if !ok {
		return 1
	}
	if s.Type == "plist" {
		plist := filepath.Join(c.home, "Library", "LaunchAgents", s.Label+".plist")
		if !fileExists(plist) {
			fmt.Fprintf(os.Stderr, "zsvc: [err] %s: LaunchAgent plist missing: %s\n", s.Display, plist)
			return 1
		}
		if _, rc := runCmdOut(2*time.Second, "launchctl", "print", fmt.Sprintf("gui/%s/%s", c.uid, s.Label)); rc == 0 {
			fmt.Fprintf(os.Stderr, "zsvc: [ok]  %s already running\n", s.Display)
			return 0
		}
		fmt.Fprintf(os.Stderr, "zsvc: starting %s (launchctl bootstrap)...\n", s.Display)
		return runPassThrough("launchctl", "bootstrap", "gui/"+c.uid, plist)
	}
	if s.Type == "launchd" && s.Install != "" {
		plist := filepath.Join(c.home, "Library", "LaunchAgents", s.Label+".plist")
		if !fileExists(plist) {
			fmt.Fprintf(os.Stderr, "zsvc: [!!]  %s plist missing — running install first\n", s.Display)
			return runPassThrough(c.ctlPath(s), s.Install)
		}
	}
	fmt.Fprintf(os.Stderr, "zsvc: starting %s...\n", s.Display)
	return runPassThrough(c.ctlPath(s), s.Start)
}

func cmdStop(c envCtx, target string) int {
	s, ok := c.mustResolve(target)
	if !ok {
		return 1
	}
	if s.Type == "plist" {
		fmt.Fprintf(os.Stderr, "zsvc: stopping %s (launchctl bootout)...\n", s.Display)
		return runPassThrough("launchctl", "bootout", fmt.Sprintf("gui/%s/%s", c.uid, s.Label))
	}
	fmt.Fprintf(os.Stderr, "zsvc: stopping %s...\n", s.Display)
	return runPassThrough(c.ctlPath(s), s.Stop)
}

func cmdRestart(c envCtx, target string) int {
	s, ok := c.mustResolve(target)
	if !ok {
		return 1
	}
	if s.Type == "plist" {
		fmt.Fprintf(os.Stderr, "zsvc: restarting %s (launchctl kickstart -k)...\n", s.Display)
		return runPassThrough("launchctl", "kickstart", "-k", fmt.Sprintf("gui/%s/%s", c.uid, s.Label))
	}
	if s.Restart != "" {
		fmt.Fprintf(os.Stderr, "zsvc: restarting %s...\n", s.Display)
		return runPassThrough(c.ctlPath(s), s.Restart)
	}
	fmt.Fprintf(os.Stderr, "zsvc: restarting %s (stop + start)...\n", s.Display)
	_ = runPassThrough(c.ctlPath(s), s.Stop)
	time.Sleep(2 * time.Second)
	return runPassThrough(c.ctlPath(s), s.Start)
}

func cmdWait(c envCtx, args []string) int {
	svcName := args[0]
	timeout := 30
	for i := 1; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--timeout":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "zsvc: [err] wait: --timeout needs a value")
				return 1
			}
			i++
			n, err := strconv.Atoi(args[i])
			if err != nil || n <= 0 {
				fmt.Fprintf(os.Stderr, "zsvc: [err] wait: --timeout must be a positive integer (got: %s)\n", args[i])
				return 1
			}
			timeout = n
		case strings.HasPrefix(a, "--timeout="):
			val := strings.TrimPrefix(a, "--timeout=")
			n, err := strconv.Atoi(val)
			if err != nil || n <= 0 {
				fmt.Fprintf(os.Stderr, "zsvc: [err] wait: --timeout must be a positive integer (got: %s)\n", val)
				return 1
			}
			timeout = n
		default:
			fmt.Fprintf(os.Stderr, "zsvc: [err] wait: unknown option: %s\n", a)
			return 1
		}
	}

	s, ok := c.mustResolve(svcName)
	if !ok {
		return 1
	}
	if probeHealthy(c, s) {
		fmt.Fprintf(os.Stderr, "zsvc: [ok]  %s already healthy\n", s.Display)
		return 0
	}
	fmt.Fprintf(os.Stderr, "zsvc: waiting for %s to become healthy (timeout %ds)...\n", s.Display, timeout)
	for elapsed := 1; elapsed <= timeout; elapsed++ {
		time.Sleep(1 * time.Second)
		if probeHealthy(c, s) {
			fmt.Fprintf(os.Stderr, "zsvc: [ok]  %s healthy after %ds\n", s.Display, elapsed)
			return 0
		}
	}
	fmt.Fprintf(os.Stderr, "zsvc: [err] %s not healthy after %ds\n", s.Display, timeout)
	return 1
}

func cmdReload(c envCtx, target string) int {
	s, ok := c.mustResolve(target)
	if !ok {
		return 1
	}
	if s.Type == "nginx" && s.Ctl != "" {
		return runPassThrough(c.ctlPath(s), "reload")
	}
	fmt.Fprintf(os.Stderr, "zsvc: [!!]  %s has no graceful reload — use: zsvc restart %s\n", s.Display, s.Name)
	return 1
}

func cmdStatus(c envCtx, args []string) int {
	s, ok := c.mustResolve(args[0])
	if !ok {
		return 1
	}
	if s.Type == "plist" {
		st, pid := probeState(c, s)
		if st == "running" {
			fmt.Fprintf(os.Stderr, "zsvc: [ok]  %s %s (pid %s, %s)\n", s.Display, st, pid, s.Endpoint)
		} else {
			fmt.Fprintf(os.Stderr, "zsvc: [!!]  %s %s\n", s.Display, st)
		}
		if probeHealthy(c, s) {
			fmt.Fprintf(os.Stderr, "zsvc: [ok]  %s\n", s.Detail)
		} else {
			fmt.Fprintf(os.Stderr, "zsvc: [!!]  unhealthy (%s)\n", s.Detail)
		}
		return 0
	}
	return runPassThrough(c.ctlPath(s), append([]string{s.Status}, args[1:]...)...)
}

func cmdLogs(c envCtx, args []string) int {
	if args[0] == "all" || args[0] == "--all" {
		return cmdLogsAll(c, args[1:])
	}
	s, ok := c.mustResolve(args[0])
	if !ok {
		return 1
	}
	if s.Logs != "" {
		return runPassThrough(c.ctlPath(s), s.Logs)
	}
	if s.Log != "" {
		_ = os.MkdirAll(filepath.Dir(s.Log), 0o755)
		fmt.Fprintf(os.Stderr, "zsvc: tailing %s — Ctrl+C to stop\n", s.Log)
		return tailExec([]string{"-f", s.Log})
	}
	fmt.Fprintf(os.Stderr, "zsvc: [err] %s has no log source\n", s.Display)
	return 1
}

func cmdLogsAll(c envCtx, args []string) int {
	lines := 50
	pathsOnly := false
	follow := true
	jsonMode := false
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--paths":
			pathsOnly = true
		case a == "--json":
			jsonMode = true
			pathsOnly = true
		case a == "--no-follow":
			follow = false
		case a == "-n" || a == "--lines":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "zsvc: [err] --lines requires a number")
				return 1
			}
			i++
			n, err := strconv.Atoi(args[i])
			if err != nil {
				fmt.Fprintf(os.Stderr, "zsvc: [err] invalid lines: %s\n", args[i])
				return 1
			}
			lines = n
		case strings.HasPrefix(a, "--lines="):
			n, err := strconv.Atoi(strings.TrimPrefix(a, "--lines="))
			if err != nil {
				fmt.Fprintf(os.Stderr, "zsvc: [err] invalid lines\n")
				return 1
			}
			lines = n
		default:
			fmt.Fprintf(os.Stderr, "zsvc: [err] unknown logs all option: %s\n", a)
			return 1
		}
	}

	if jsonMode {
		type src struct {
			Name    string `json:"name"`
			Display string `json:"display"`
			Path    string `json:"path"`
			Exists  bool   `json:"exists"`
		}
		var srcs []src
		for _, s := range c.services {
			if s.Log == "" {
				continue
			}
			srcs = append(srcs, src{Name: s.Name, Display: s.Display, Path: s.Log, Exists: fileExists(s.Log)})
		}
		b, _ := json.Marshal(struct {
			Sources     []src  `json:"sources"`
			TailCommand string `json:"tail_command"`
		}{Sources: srcs, TailCommand: "zsvc logs all"})
		fmt.Println(string(b))
		return 0
	}

	var files []string
	for _, s := range c.services {
		if s.Log == "" {
			continue
		}
		if pathsOnly {
			fmt.Printf("%-16s %s\n", s.Display, s.Log)
		} else {
			_ = os.MkdirAll(filepath.Dir(s.Log), 0o755)
			files = append(files, s.Log)
		}
	}
	if pathsOnly {
		return 0
	}
	if len(files) == 0 {
		fmt.Fprintln(os.Stderr, "zsvc: [err] no log sources registered")
		return 1
	}
	if follow {
		fmt.Fprintln(os.Stderr, "zsvc: tailing all registered logs — Ctrl+C to stop")
		return tailExec(append([]string{"-n", strconv.Itoa(lines), "-F"}, files...))
	}
	return tailExec(append([]string{"-n", strconv.Itoa(lines)}, files...))
}

func cmdDiag(c envCtx, target string) int {
	s, ok := c.mustResolve(target)
	if !ok {
		return 1
	}
	fmt.Printf("\n==> zsvc diag: %s\n", s.Display)
	fmt.Println("\n--- status ---")
	if s.Type == "plist" {
		_ = cmdStatus(c, []string{target})
	} else {
		_ = runPassThrough(c.ctlPath(s), s.Status)
	}
	if s.Validate != "" {
		fmt.Println("\n--- validate ---")
		_ = runPassThrough(c.ctlPath(s), s.Validate)
	}
	if s.Type == "launchd" || s.Type == "plist" {
		fmt.Println("\n--- launchd state ---")
		if out, rc := runCmdOut(3*time.Second, "launchctl", "print", fmt.Sprintf("gui/%s/%s", c.uid, s.Label)); rc == 0 {
			fmt.Print(out)
		} else {
			fmt.Println("(not registered)")
		}
	} else if s.Type == "nginx" {
		fmt.Println("\n--- launchd state (system domain) ---")
		if out, rc := runCmdOut(3*time.Second, "launchctl", "print", "system/"+s.Label); rc == 0 {
			fmt.Print(out)
		} else {
			fmt.Println("(not registered)")
		}
	}
	if s.Log != "" {
		fmt.Printf("\n--- last 50 log lines — %s ---\n", s.Log)
		if fileExists(s.Log) {
			_ = runPassThrough("tail", "-50", s.Log)
		} else {
			fmt.Println("(log not found — service may not have started yet)")
		}
	}
	fmt.Println("\n--- suggested commands ---")
	fmt.Printf("  zsvc logs %s\n", s.Name)
	fmt.Printf("  zsvc restart %s\n", s.Name)
	if s.Validate != "" {
		fmt.Printf("  zsvc validate %s\n", s.Name)
	}
	fmt.Printf("  log show --style compact --last 5m --predicate 'eventMessage CONTAINS \"%s\"'\n", s.Label)
	return 0
}

func cmdValidate(c envCtx, target string) int {
	s, ok := c.mustResolve(target)
	if !ok {
		return 1
	}
	if s.Validate != "" {
		return runPassThrough(c.ctlPath(s), s.Validate)
	}
	fmt.Fprintf(os.Stderr, "zsvc: [!!]  %s has no validate command\n", s.Display)
	return 1
}

func probeState(c envCtx, s svcDesc) (string, string) {
	if s.Type == "colima" {
		if _, rc := runCmdOut(2*time.Second, "colima", "status"); rc == 0 {
			return "running", "-"
		}
		return "stopped", "-"
	}
	if s.Type == "derived" {
		return "n/a", "-"
	}
	target := fmt.Sprintf("gui/%s/%s", c.uid, s.Label)
	if s.Type == "nginx" {
		target = "system/" + s.Label
	}
	out, rc := runCmdOut(2*time.Second, "launchctl", "print", target)
	if rc != 0 {
		return "not-registered", "-"
	}
	state, pid := "unknown", "-"
	for _, ln := range strings.Split(out, "\n") {
		tr := strings.TrimSpace(ln)
		if state == "unknown" && strings.HasPrefix(tr, "state = ") {
			state = strings.TrimPrefix(tr, "state = ")
		}
		if pid == "-" && strings.HasPrefix(tr, "pid = ") {
			pid = strings.TrimPrefix(tr, "pid = ")
		}
	}
	return state, pid
}

func probeHealthy(c envCtx, s svcDesc) bool {
	switch s.Name {
	case "llama", "embed":
		return httpOK(s.Endpoint+"/health", 3*time.Second)
	case "o2", "status":
		return httpOK(s.Endpoint+"/healthz", 3*time.Second)
	case "jaeger", "gemstash":
		return httpOK(s.Endpoint+"/", 3*time.Second)
	case "nginx":
		client := &http.Client{Timeout: 3 * time.Second}
		resp, err := client.Get("http://localhost/")
		if err != nil {
			return false
		}
		_ = resp.Body.Close()
		return true
	case "otel":
		_, rc := runCmdOut(3*time.Second, filepath.Join(c.binDir, "otel-collector"), "health")
		return rc == 0
	case "worker":
		_, rc := runCmdOut(3*time.Second, filepath.Join(c.binDir, "zdots-worker"), "health")
		return rc == 0
	case "colima":
		_, rc := runCmdOut(3*time.Second, "colima", "status")
		return rc == 0
	case "postgres":
		_, rc := runCmdOut(2*time.Second, "pg_isready", "-q")
		return rc == 0
	case "redis":
		return redisPing(net.JoinHostPort(c.redisHost, c.redisPort), 1*time.Second)
	}
	return false
}

func redisPing(addr string, timeout time.Duration) bool {
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return false
	}
	defer func() { _ = conn.Close() }()
	_ = conn.SetDeadline(time.Now().Add(timeout))
	if _, err := conn.Write([]byte("PING\r\n")); err != nil {
		return false
	}
	var buf [16]byte
	n, err := conn.Read(buf[:])
	return err == nil && strings.Contains(string(buf[:n]), "PONG")
}

func httpOK(url string, timeout time.Duration) bool {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(url)
	if err != nil {
		return false
	}
	_ = resp.Body.Close()
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

func brewLabel(home, formula string) string {
	sysDir := envOr("ZDOTS_LAUNCHD_SYSTEM_DIR", "/Library/LaunchDaemons")
	dirs := []string{filepath.Join(home, "Library", "LaunchAgents"), sysDir}
	for _, d := range dirs {
		if fileExists(filepath.Join(d, "sh.brew."+formula+".plist")) {
			return "sh.brew." + formula
		}
	}
	for _, d := range dirs {
		if fileExists(filepath.Join(d, "homebrew.mxcl."+formula+".plist")) {
			return "homebrew.mxcl." + formula
		}
	}
	return "sh.brew." + formula
}

func runPassThrough(name string, args ...string) int {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}
		return 1
	}
	return 0
}

func tailExec(args []string) int {
	cmd := exec.Command("tail", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	if err := cmd.Start(); err != nil {
		return 1
	}
	go func() {
		<-sigCh
		if cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGTERM)
		}
	}()
	_ = cmd.Wait()
	return 0
}

func runCmdOut(timeout time.Duration, name string, args ...string) (string, int) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).CombinedOutput()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return string(out), exitErr.ExitCode()
		}
		return string(out), 1
	}
	return string(out), 0
}

func bracketIPv6(h string) string {
	if strings.Contains(h, ":") && !strings.HasPrefix(h, "[") {
		return "[" + h + "]"
	}
	return h
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
