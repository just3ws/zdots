package ctl

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/ctlstatus"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

func usage() string {
	return `Usage: zdots-ctl <command> [options]

Platform Lifecycle:
  up        Start all services in dependency order (idempotent)
  down      Stop all services cleanly (reverse dependency order)
  reset     down + up — full platform restart
  install   First-time setup: install binaries, register launchd agents, start

Diagnostics:
  check     Deep environment check — tools, configs, services, disk, OTel pipeline
  status    Live service status (quick)
  status --json  Same as JSON

Dependency order (up):
  1. OpenObserve          (openobserve-ctl start)
  2. otel-collector       (otel-collector start)
  3. AI server            (llama-ctl start)
  4. Embed server         (llama-ctl start-embed)

Readiness:
  zsvc list                       Verify service registration
  bats tests/platform_e2e.bats    Live branch-readiness suite
  docs/platform-service-plane.md  Lifecycle diagrams and isolation playbook

Environment:
  ZDOTS_BOOT_TIMEOUT   Seconds to wait per service health check (default: 90)
  ZDOTS_AI_ENDPOINT    AI server base URL (default: http://127.0.0.1:11500)

Options:
  -h, --help    Show this help
`
}

type cfg struct {
	home          string
	zdotdir       string
	binDir        string
	xdgState      string
	aiEndpoint    string
	embedEndpoint string
	otlpEndpoint  string
	o2Endpoint    string
	redisHost     string
	redisPort     string
	waitTimeout   int
}

func loadCfg() cfg {
	home, _ := os.UserHomeDir()
	zdotdir := envOr("ZDOTDIR", filepath.Join(home, ".config", "zsh"))
	binDir := filepath.Join(zdotdir, "bin")
	if exe, err := filepath.Abs(os.Args[0]); err == nil {
		if d := filepath.Dir(exe); d != "" && d != "." {
			binDir = d
		}
	}
	aiHost := bracketIPv6(envOr("ZDOTS_AI_HOST", "127.0.0.1"))
	embedHost := bracketIPv6(envOr("ZDOTS_AI_EMBED_HOST", "127.0.0.1"))
	otelHost := bracketIPv6(envOr("ZDOTS_OTEL_HOST", "127.0.0.1"))
	o2Host := bracketIPv6(envOr("ZDOTS_O2_HOST", "127.0.0.1"))

	waitTimeout := 90
	if wt, err := strconv.Atoi(envOr("ZDOTS_BOOT_TIMEOUT", "90")); err == nil && wt > 0 {
		waitTimeout = wt
	}

	return cfg{
		home:          home,
		zdotdir:       zdotdir,
		binDir:        binDir,
		xdgState:      envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state")),
		aiEndpoint:    envOr("ZDOTS_AI_ENDPOINT", fmt.Sprintf("http://%s:%s", aiHost, envOr("ZDOTS_AI_PORT", "11500"))),
		embedEndpoint: envOr("ZDOTS_AI_EMBED_ENDPOINT", fmt.Sprintf("http://%s:%s", embedHost, envOr("ZDOTS_EMBED_PORT", "11501"))),
		otlpEndpoint:  envOr("ZDOTS_OTLP_ENDPOINT", fmt.Sprintf("http://%s:%s", otelHost, envOr("ZDOTS_OTEL_HTTP_PORT", "4318"))),
		o2Endpoint:    envOr("ZDOTS_O2_ENDPOINT", fmt.Sprintf("http://%s:%s", o2Host, envOr("ZDOTS_O2_PORT", "5080"))),
		redisHost:     envOr("ZDOTS_REDIS_HOST", "127.0.0.1"),
		redisPort:     envOr("ZDOTS_REDIS_PORT", "6379"),
		waitTimeout:   waitTimeout,
	}
}

// Run executes the zdots-ctl command and returns the process exit code.
func Run(args []string) int {
	for _, a := range args {
		if a == "-h" || a == "--help" {
			fmt.Print(usage())
			return 0
		}
	}
	if len(args) == 0 {
		fmt.Fprint(os.Stderr, usage())
		return 1
	}

	cmd := args[0]
	rest := args[1:]
	c := loadCfg()

	tr := otel.New("zdots-ctl")
	sp := tr.Start("ctl."+cmd, nil)

	var rc int
	switch cmd {
	case "up":
		if len(rest) > 0 {
			rc = rejectExtraArgs("up", rest)
		} else {
			rc = cmdUp(c, tr, sp)
		}
	case "down":
		if len(rest) > 0 {
			rc = rejectExtraArgs("down", rest)
		} else {
			rc = cmdDown(c)
		}
	case "reset":
		if len(rest) > 0 {
			rc = rejectExtraArgs("reset", rest)
		} else {
			rc = cmdReset(c, tr, sp)
		}
	case "install":
		if len(rest) > 0 {
			rc = rejectExtraArgs("install", rest)
		} else {
			rc = cmdInstall(c, tr, sp)
		}
	case "check":
		out, code := runCheck(c, tr, sp)
		fmt.Print(out)
		rc = code
	case "status":
		rc = cmdStatus(c, rest, tr, sp)
	default:
		fmt.Fprintf(os.Stderr, "zdots-ctl: unknown command: %s\n", cmd)
		fmt.Fprint(os.Stderr, usage())
		rc = 1
	}

	sp.SetAttr("exit_code", rc)
	sp.End(rc == 0, "")
	tr.Flush(250 * time.Millisecond)
	return rc
}

// CheckText runs `zdots-ctl check` and returns the formatted output and exit code.
func CheckText(zdotdir string) (string, int) {
	c := loadCfg()
	if zdotdir != "" {
		c.zdotdir = zdotdir
		c.binDir = filepath.Join(zdotdir, "bin")
	}
	return runCheck(c, nil, nil)
}

func rejectExtraArgs(cmd string, rest []string) int {
	fmt.Fprintf(os.Stderr, "zdots-ctl: %s takes no arguments (got: %s)\n", cmd, strings.Join(rest, " "))
	fmt.Fprint(os.Stderr, usage())
	return 1
}

func info(msg string)    { fmt.Fprintf(os.Stderr, "zdots-ctl: %s\n", msg) }
func ok(msg string)      { fmt.Fprintf(os.Stderr, "zdots-ctl: [ok]  %s\n", msg) }
func warn(msg string)    { fmt.Fprintf(os.Stderr, "zdots-ctl: [!!]  %s\n", msg) }
func section(msg string) { fmt.Fprintf(os.Stderr, "\nzdots-ctl: ── %s ──\n", msg) }

func cmdStatus(c cfg, args []string, tr *otel.Tracer, parent *otel.Span) int {
	jsonMode := len(args) > 0 && args[0] == "--json"
	st := ctlstatus.ProbeWithTracer(c.zdotdir, tr, parent)

	if jsonMode {
		b, _ := json.Marshal(st)
		fmt.Println(string(b))
		return 0
	}

	sym := func(b bool) string {
		if b {
			return "✓"
		}
		return "✗"
	}

	fmt.Println("zdots-ctl: platform status")
	upDown := "down"
	if st.Colima {
		upDown = "up"
	}
	fmt.Printf("  %-20s %s  %s\n", "colima", sym(st.Colima), upDown)
	fmt.Printf("  %-20s %s  %s\n", "jaeger", sym(st.Jaeger), st.JaegerURL)
	fmt.Printf("  %-20s %s  %s\n", "otel-collector", sym(st.OTelCollector), st.OTLPEndpoint)
	fmt.Printf("  %-20s %s  %s (socket: %v)\n", "AI server", sym(st.AIServer), st.AIEndpoint, st.AISocketListening)
	fmt.Printf("  %-20s %s  %s\n", "embed server", sym(st.EmbedServer), st.EmbedEndpoint)
	fmt.Printf("  %-20s %s  %s\n", "intelligence", sym(st.IntelligenceSuite), "postgres")
	fmt.Printf("  %-20s %s  %s:%d\n", "cache", sym(st.Cache), st.RedisHost, st.RedisPort)
	fmt.Printf("  %-20s %s  %s\n", "worker", sym(st.Worker), "jobs queue (my)")

	if !st.AIServer || !st.EmbedServer || !st.OTelCollector {
		fmt.Println("\nzdots-ctl: to start all: zdots-ctl up")
	}
	return 0
}

func cmdUp(c cfg, tr *otel.Tracer, parent *otel.Span) int {
	section("Bringing platform up")
	appendTraceLog(c.xdgState, "platform_up", "start")

	// 1. OpenObserve
	if httpOK(c.o2Endpoint+"/healthz", 2*time.Second) {
		ok("OpenObserve already up")
	} else if svcRegistered(c, "com.zdots.openobserve") {
		info("starting OpenObserve...")
		if err := runBin(c, "openobserve-ctl", "start"); err != nil {
			fmt.Fprintf(os.Stderr, "zdots-ctl: [err] openobserve-ctl start failed: %v\n", err)
			return 1
		}
		if !waitFor("OpenObserve", c.o2Endpoint+"/healthz", 60) {
			return 1
		}
		ok("OpenObserve up")
	} else {
		info("OpenObserve not registered — skipping (optional services tier)")
	}

	// 2. otel-collector
	if launchdRunning("com.zdots.otel-collector") {
		ok("otel-collector already running")
	} else if svcRegistered(c, "com.zdots.otel-collector") {
		info("starting otel-collector...")
		_ = runBin(c, "otel-collector", "start")
		time.Sleep(2 * time.Second)
		if launchdRunning("com.zdots.otel-collector") {
			ok("otel-collector up")
		} else {
			warn("otel-collector did not start — run: otel-collector install")
		}
	} else {
		info("otel-collector not registered — skipping (optional services tier)")
	}

	// 3. AI server
	if httpOK(c.aiEndpoint+"/health", 2*time.Second) {
		ok("AI server already up")
	} else {
		info("starting AI server...")
		_ = runBin(c, "llama-ctl", "start")
		aiWait := 90
		if v, err := strconv.Atoi(os.Getenv("ZDOTS_AI_WAIT")); err == nil && v > 0 {
			aiWait = v
		}
		if waitForSoft(c.aiEndpoint+"/health", aiWait) {
			ok("AI server up")
		} else {
			fmt.Fprintln(os.Stderr, "zdots-ctl: [err] AI server not ready — likely slow load/OOM under memory pressure. diagnose: zsvc diag llama | budget: ZDOTS_AI_WAIT=180 zdots-ctl up")
			return 1
		}
	}

	// 4. Embed server
	if httpOK(c.embedEndpoint+"/health", 2*time.Second) {
		ok("embed server already up")
	} else {
		info("starting embed server...")
		if err := runBin(c, "llama-ctl", "start-embed"); err == nil {
			ok("embed server up")
		} else {
			warn("embed server not ready (RAG/capture disabled) — likely memory pressure")
			warn("  retry: zsvc restart embed | diagnose: zsvc diag embed | budget: ZDOTS_EMBED_WAIT=120")
		}
	}

	// 5. Worker
	if launchdRunning("com.zdots.worker") {
		ok("worker already running")
	} else {
		info("starting worker...")
		_ = runBin(c, "zdots-worker", "start")
		time.Sleep(2 * time.Second)
		if launchdRunning("com.zdots.worker") {
			ok("worker up")
		} else {
			warn("worker did not start — run: zdots-worker install")
		}
	}

	section("Platform status")
	cmdStatus(c, nil, tr, parent)
	appendTraceLog(c.xdgState, "platform_up", "complete")
	return 0
}

func cmdDown(c cfg) int {
	section("Bringing platform down")
	appendTraceLog(c.xdgState, "platform_down", "start")
	info("stopping worker...")
	_ = runBinQuiet(c, "zdots-worker", "stop")
	info("stopping otel-collector...")
	_ = runBinQuiet(c, "otel-collector", "stop")
	info("stopping embed server...")
	_ = runBinQuiet(c, "llama-ctl", "stop-embed")
	info("stopping AI server...")
	_ = runBinQuiet(c, "llama-ctl", "stop")
	info("stopping OpenObserve...")
	_ = runBinQuiet(c, "openobserve-ctl", "stop")
	ok("platform down")
	appendTraceLog(c.xdgState, "platform_down", "complete")
	return 0
}

func cmdReset(c cfg, tr *otel.Tracer, parent *otel.Span) int {
	section("Resetting platform")
	cmdDown(c)
	time.Sleep(2 * time.Second)
	return cmdUp(c, tr, parent)
}

func cmdInstall(c cfg, tr *otel.Tracer, parent *otel.Span) int {
	section("Installing platform (first-time setup)")
	for _, step := range []struct {
		label string
		bin   string
		arg   string
	}{
		{"installing llama.cpp...", "llama-ctl", "install"},
		{"installing embed server...", "llama-ctl", "install-embed"},
		{"installing otel-collector...", "otel-collector", "install"},
		{"installing worker...", "zdots-worker", "install"},
	} {
		info(step.label)
		if err := runBin(c, step.bin, step.arg); err != nil {
			fmt.Fprintf(os.Stderr, "zdots-ctl: [err] %s %s failed: %v\n", step.bin, step.arg, err)
			return 1
		}
	}
	section("Starting platform")
	if rc := cmdUp(c, tr, parent); rc != 0 {
		return rc
	}
	section("Validating environment")
	if err := runBin(c, "capabilities"); err != nil {
		return 1
	}
	return 0
}

type chkSection struct {
	lines    []string
	errors   int
	warnings int
}

func (s *chkSection) pass(msg string) { s.lines = append(s.lines, "  [PASS] "+msg) }
func (s *chkSection) warn(msg string) {
	s.warnings++
	s.lines = append(s.lines, "  [WARN] "+msg)
}
func (s *chkSection) fail(msg string) {
	s.errors++
	s.lines = append(s.lines, "  [FAIL] "+msg)
}
func (s *chkSection) fix(msg string)  { s.lines = append(s.lines, "         fix: "+msg) }
func (s *chkSection) info(msg string) { s.lines = append(s.lines, msg) }

func runCheck(c cfg, tr *otel.Tracer, parent *otel.Span) (string, int) {
	appendTraceLog(c.xdgState, "platform_check", "start")

	st := ctlstatus.ProbeWithTracer(c.zdotdir, tr, parent)

	type task struct {
		name string
		fn   func() chkSection
	}
	tasks := []task{
		{"ctl.check.tools", func() chkSection { return chkTools() }},
		{"ctl.check.configs", func() chkSection { return chkConfigs(c) }},
		{"ctl.check.storage", func() chkSection { return chkStorage(c) }},
		{"ctl.check.services", func() chkSection { return chkServices(c, st) }},
		{"ctl.check.proxy", func() chkSection { return chkProxy(c) }},
		{"ctl.check.ai_router", func() chkSection { return chkAIRouter(c) }},
		{"ctl.check.ai_integration", func() chkSection { return chkAIIntegration(c, st) }},
		{"ctl.check.otel", func() chkSection { return chkOTel(c, st) }},
		{"ctl.check.traces", func() chkSection { return chkTraces(c) }},
	}
	if runtime.GOOS == "darwin" {
		tasks = append(tasks, task{"ctl.check.provenance", func() chkSection { return chkProvenance(c) }})
		if envOr("ZDOTS_CONTEXT", "home") == "work" {
			tasks = append(tasks, task{"ctl.check.work_security", func() chkSection { return chkWorkSecurity(c) }})
		}
	}

	res := make([]chkSection, len(tasks))
	var wg sync.WaitGroup
	for i, t := range tasks {
		wg.Add(1)
		go func(idx int, tk task) {
			defer wg.Done()
			var sp *otel.Span
			if tr != nil {
				sp = tr.Start(tk.name, parent)
			}
			sec := tk.fn()
			res[idx] = sec
			if sp != nil {
				sp.SetAttr("errors", sec.errors)
				sp.SetAttr("warnings", sec.warnings)
				sp.End(sec.errors == 0, "")
			}
		}(i, t)
	}
	wg.Wait()

	var buf bytes.Buffer
	fmt.Fprintf(&buf, "zdots-ctl check — %s\n\n", time.Now().Format("2006-01-02 15:04:05"))
	totalErrs, totalWarns := 0, 0
	for i, sec := range res {
		if i > 0 && len(sec.lines) > 0 {
			buf.WriteByte('\n')
		}
		for _, ln := range sec.lines {
			buf.WriteString(ln)
			buf.WriteByte('\n')
		}
		totalErrs += sec.errors
		totalWarns += sec.warnings
	}

	buf.WriteByte('\n')
	if totalErrs == 0 && totalWarns == 0 {
		fmt.Fprintln(&buf, "zdots-ctl check: all checks passed")
	} else if totalErrs == 0 {
		fmt.Fprintf(&buf, "zdots-ctl check: passed with %d warning(s)\n", totalWarns)
	} else {
		fmt.Fprintf(&buf, "zdots-ctl check: %d failure(s), %d warning(s)\n", totalErrs, totalWarns)
	}

	appendTraceLog(c.xdgState, "platform_check", fmt.Sprintf("complete errors=%d warnings=%d", totalErrs, totalWarns))
	if totalErrs == 0 {
		return buf.String(), 0
	}
	return buf.String(), 1
}

func chkTools() chkSection {
	var s chkSection
	s.info("Required tools (Core)")
	for _, tool := range []string{"brew", "git", "curl", "jq", "yq", "llama-server"} {
		if p, err := exec.LookPath(tool); err == nil {
			s.pass(tool + "  " + p)
		} else {
			s.fail(tool + "  not found")
			s.fix("brew install " + tool)
		}
	}
	s.info("\nOptional tools (Services & Ingress)")
	nginxHdr := nginxServerHeader(1 * time.Second)
	for _, tool := range []string{"otelcol-contrib", "colima", "docker", "nginx", "mkcert"} {
		if p, err := exec.LookPath(tool); err == nil {
			s.pass(tool + "  " + p)
		} else if tool == "nginx" && strings.Contains(strings.ToLower(nginxHdr), "nginx") {
			s.pass(tool + "  running as system service (port 80)")
		} else {
			s.pass(tool + "  not installed (optional tier)")
		}
	}
	return s
}

func chkConfigs(c cfg) chkSection {
	var s chkSection
	s.info("Config files")
	for _, f := range []struct{ label, path string }{
		{"ai-models.yaml", filepath.Join(c.zdotdir, "etc", "ai-models.yaml")},
		{"otel-collector.yaml", filepath.Join(c.zdotdir, "etc", "otel-collector.yaml")},
	} {
		if fileExists(f.path) {
			s.pass(f.label + "  " + f.path)
		} else {
			s.fail(f.label + "  missing: " + f.path)
		}
	}
	for _, p := range []struct{ label, plist, fix string }{
		{"llama-server plist", "com.zdots.llama-server.plist", "llama-ctl install"},
		{"llama-embed plist ", "com.zdots.llama-embed.plist", "ZDOTS_AI_PROFILE=embed llama-ctl model-download && llama-ctl install-embed"},
		{"otel-collector plist", "com.zdots.otel-collector.plist", "otel-collector install"},
	} {
		full := filepath.Join(c.home, "Library", "LaunchAgents", p.plist)
		if fileExists(full) {
			s.pass(p.label + "  " + full)
		} else {
			s.warn(p.label + "  not registered")
			s.fix(p.fix)
		}
	}

	s.info("\nConfig validity")
	if _, err := exec.LookPath("yq"); err == nil {
		for _, f := range []string{
			filepath.Join(c.zdotdir, "etc", "ai-models.yaml"),
			filepath.Join(c.zdotdir, "etc", "otel-collector.yaml"),
		} {
			if fileExists(f) {
				if _, rc := runCmdOut(3*time.Second, "yq", "eval", ".", f); rc == 0 {
					s.pass(filepath.Base(f) + "  valid YAML")
				} else {
					s.fail(filepath.Base(f) + "  invalid YAML")
					s.fix("yq eval . " + f)
				}
			}
		}
	} else {
		s.warn("yq not available — skipping YAML validation")
		s.fix("brew install yq")
	}
	return s
}

func chkStorage(c cfg) chkSection {
	var s chkSection
	s.info("Model storage")
	xdgData := envOr("XDG_DATA_HOME", filepath.Join(c.home, ".local", "share"))
	modelsDir := envOr("ZDOTS_AI_MODELS_DIR", filepath.Join(xdgData, "llama-cpp", "models"))
	if info, err := os.Stat(modelsDir); err == nil && info.IsDir() {
		count := 0
		_ = filepath.WalkDir(modelsDir, func(path string, d os.DirEntry, err error) error {
			if err == nil && !d.IsDir() && strings.HasSuffix(d.Name(), ".gguf") {
				count++
			}
			return nil
		})
		if count > 0 {
			s.pass(fmt.Sprintf("models dir  %s (%d GGUF file(s))", modelsDir, count))
		} else {
			s.warn("models dir exists but no .gguf files found")
			s.fix("llama-ctl model-download")
		}
	} else {
		s.warn("models dir not found: " + modelsDir)
		s.fix("llama-ctl model-download  (will create dir)")
	}

	var st syscall.Statfs_t
	if err := syscall.Statfs("/", &st); err == nil {
		availGB := (st.Bavail * uint64(st.Bsize)) / (1024 * 1024 * 1024)
		if availGB < 5 {
			s.fail(fmt.Sprintf("disk available: %dGB — critically low", availGB))
			s.fix("llama-ctl model-prune && docker-reclaim -f")
		} else if availGB < 15 {
			s.warn(fmt.Sprintf("disk available: %dGB — getting low", availGB))
			s.fix("docker-reclaim  (dry run first)")
		} else {
			s.pass(fmt.Sprintf("disk available: %dGB", availGB))
		}
	}
	return s
}

func chkServices(c cfg, st ctlstatus.Status) chkSection {
	var s chkSection
	s.info("Service health")
	if st.Jaeger {
		s.pass(fmt.Sprintf("Jaeger  reachable (%s)", st.JaegerURL))
	} else if svcRegistered(c, "com.zdots.jaeger") {
		s.warn("Jaeger  unreachable")
		s.fix("zsvc start jaeger")
	} else {
		s.pass("Jaeger  not registered (optional services tier)")
	}

	if st.Colima {
		s.pass("Colima  running (container workloads)")
	} else {
		s.pass("Colima  not running (not required — observability is native)")
	}

	if st.OTelCollector {
		s.pass("otel-collector  running")
	} else if svcRegistered(c, "com.zdots.otel-collector") {
		s.warn("otel-collector  not running")
		s.fix("zdots-ctl up")
	} else {
		s.pass("otel-collector  not registered (optional services tier)")
	}

	if st.Worker {
		s.pass("worker  running (draining job queue)")
	} else {
		s.warn("worker  not running — enqueued jobs will not process")
		s.fix("zsvc start worker  (or: zdots-ctl up)")
	}

	if st.AIServer {
		s.pass(fmt.Sprintf("AI server  reachable (%s)", c.aiEndpoint))
	} else {
		s.warn("AI server  unreachable")
		s.fix("zdots-ctl up")
	}

	if st.EmbedServer {
		s.pass(fmt.Sprintf("embed server  reachable (%s)", c.embedEndpoint))
	} else if fileExists(filepath.Join(c.home, "Library", "LaunchAgents", "com.zdots.llama-embed.plist")) {
		s.warn("embed server  registered but not serving — likely still loading or OOM (RAG/capture disabled)")
		s.fix("zsvc diag embed   (then: zsvc restart embed, or ZDOTS_EMBED_WAIT=120 zsvc start embed)")
	} else {
		s.warn("embed server  not installed — RAG/capture disabled")
		s.fix("ZDOTS_AI_PROFILE=embed llama-ctl model-download && llama-ctl install-embed")
	}

	if runtime.GOOS == "darwin" {
		llamaPlist := filepath.Join(c.home, "Library", "LaunchAgents", "com.zdots.llama-server.plist")
		if data, err := os.ReadFile(llamaPlist); err == nil {
			txt := string(data)
			if strings.Contains(txt, "<string>127.0.0.1</string>") &&
				!strings.Contains(txt, "<string>0.0.0.0</string>") &&
				!strings.Contains(txt, "<string>*</string>") {
				s.pass("llama-server plist  bound to 127.0.0.1")
			} else {
				s.fail("llama-server plist  may bind to all interfaces — run: llama-ctl install")
			}
		}
		if st.AISocketListening {
			portRe := regexp.MustCompile(`[0-9]+$`)
			port := portRe.FindString(c.aiEndpoint)
			if port != "" {
				lsofOut, _ := runCmdOut(2*time.Second, "lsof", "-nP", "-i", "TCP:"+port, "-sTCP:LISTEN")
				var nonLo []string
				for _, ln := range strings.Split(lsofOut, "\n") {
					fields := strings.Fields(ln)
					if len(fields) >= 9 && strings.HasPrefix(fields[0], "llama-ser") && !strings.HasPrefix(fields[8], "127.") {
						nonLo = append(nonLo, fields[8])
					}
				}
				if len(nonLo) > 0 {
					s.fail("llama-server  socket exposed on non-loopback: " + strings.Join(nonLo, " "))
				} else {
					s.pass("llama-server  socket bound to loopback only")
				}
			}
		}
		xdgData := envOr("XDG_DATA_HOME", filepath.Join(c.home, ".local", "share"))
		modelsDir := envOr("ZDOTS_AI_MODELS_DIR", filepath.Join(xdgData, "llama-cpp", "models"))
		if info, err := os.Stat(modelsDir); err == nil && info.IsDir() {
			perm := fmt.Sprintf("%o", info.Mode().Perm())
			if perm == "700" {
				s.pass(fmt.Sprintf("llama models dir  700 (%s)", modelsDir))
			} else {
				s.warn(fmt.Sprintf("llama models dir  permissions %s (expected 700)", perm))
				s.fix("chmod 700 " + modelsDir)
			}
		}
	}

	if st.IntelligenceSuite {
		s.pass("intelligence  connected (postgres)")
	} else {
		s.warn("intelligence  unreachable (check ZDOTS_DATABASE_URL and postgres)")
		s.fix("zdots-ctx status")
	}

	if st.Cache {
		s.pass(fmt.Sprintf("cache  Redis reachable (%s:%s)", c.redisHost, c.redisPort))
	} else if svcRegistered(c, "redis") {
		s.warn("cache  Redis unreachable — analytics writes fall back to SQLite")
		s.fix("zsvc start redis")
	} else {
		s.pass("cache  Redis not registered — analytics writes use SQLite directly")
	}
	return s
}

func chkProxy(c cfg) chkSection {
	var s chkSection
	s.info("Local proxy (optional ingress tier)")
	hdr := nginxServerHeader(2 * time.Second)
	nginxReg := svcRegistered(c, "nginx")
	if strings.Contains(strings.ToLower(hdr), "nginx") {
		s.pass("nginx  running on port 80")
		s.pass("nginx config  valid (inferred — service is running)")
	} else if nginxReg {
		s.warn("nginx  registered but not running")
		s.fix("zsvc start nginx")
	} else {
		s.pass("nginx  not registered (direct loopback mode)")
	}

	if _, err := exec.LookPath("mkcert"); err == nil {
		caroot, _ := runCmdOut(2*time.Second, "mkcert", "-CAROOT")
		caroot = strings.TrimSpace(caroot)
		caFile := filepath.Join(caroot, "rootCA.pem")
		if fileExists(caFile) {
			if _, rc := runCmdOut(3*time.Second, "security", "verify-cert", "-c", caFile); rc == 0 {
				s.pass("mkcert CA  trusted in system keychain")
			} else {
				s.warn("mkcert CA  present but NOT trusted — HTTPS certs will show browser warnings")
				s.fix("mkcert -install  (needs macOS password)")
			}
		} else {
			s.warn("mkcert CA  not generated yet")
			s.fix("mkcert -install")
		}
		brewPfx := envOr("HOMEBREW_PREFIX", "/opt/homebrew")
		certFile := filepath.Join(brewPfx, "etc", "nginx", "certs", "zdots-local.pem")
		if fileExists(certFile) {
			s.pass("nginx TLS certs  present (" + certFile + ")")
		} else if nginxReg {
			s.warn("nginx TLS certs  missing")
			s.fix("run bin/bootstrap")
		} else {
			s.pass("nginx TLS certs  not provisioned (direct loopback mode)")
		}
	} else if nginxReg {
		s.warn("mkcert  not installed")
		s.fix("brew install mkcert && mkcert -install")
	} else {
		s.pass("mkcert  not installed (direct loopback mode)")
	}
	return s
}

func chkAIRouter(c cfg) chkSection {
	var s chkSection
	s.info("AI router")
	ask := filepath.Join(c.zdotdir, "bin", "zdots-ask")
	quiz := filepath.Join(c.zdotdir, "bin", "zdots-quiz")
	if info, err := os.Stat(ask); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
		s.pass("zdots-ask  executable")
	} else {
		s.fail("zdots-ask  not found or not executable: " + ask)
	}
	missing := 0
	for _, d := range []string{"default", "shell", "ruby", "phi"} {
		if !fileExists(filepath.Join(c.zdotdir, "etc", "prompts", "zdots-"+d+".md")) {
			s.fail(fmt.Sprintf("prompt  zdots-%s.md missing", d))
			missing++
		}
	}
	if missing == 0 {
		s.pass("prompts  all 4 domain prompts present")
	}
	if info, err := os.Stat(ask); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
		out, _ := runCmdEnvOut(4*time.Second, []string{"ZDOTS_AI_MODE=none"}, ask, "--dry-run", "write a ZLE widget")
		det := ""
		for _, ln := range strings.Split(out, "\n") {
			if idx := strings.Index(ln, "domain="); idx >= 0 {
				rest := ln[idx+len("domain="):]
				if sp := strings.IndexByte(rest, ' '); sp >= 0 {
					det = rest[:sp]
				} else {
					det = rest
				}
				break
			}
		}
		if det == "shell" {
			s.pass("router  domain detection correct (shell detected for ZLE prompt)")
		} else {
			if det == "" {
				det = "empty"
			}
			s.warn(fmt.Sprintf("router  domain detection returned '%s' for ZLE prompt (expected 'shell')", det))
		}
	}
	if info, err := os.Stat(quiz); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
		s.pass("zdots-quiz  executable (run 'zdots-quiz --quick' to probe model capability)")
	} else {
		s.warn("zdots-quiz  not found: " + quiz)
	}
	return s
}

func chkAIIntegration(c cfg, st ctlstatus.Status) chkSection {
	var s chkSection
	s.info("AI integration")
	llamaTest := filepath.Join(c.zdotdir, "tests", "llama_integration.rb")
	if _, err := exec.LookPath("zdots-ruby"); err != nil {
		s.warn("zdots-ruby not in PATH — AI integration test skipped")
		s.fix(fmt.Sprintf("ensure %s/bin is in PATH", c.zdotdir))
		return s
	}
	if !fileExists(llamaTest) {
		s.warn("AI integration test not found: " + llamaTest)
		return s
	}
	if _, rc := runCmdOut(4*time.Second, "zdots-ruby", "-e", `require "ruby_llm"`); rc != 0 {
		s.warn("ruby_llm gem not available — AI integration test skipped")
		s.fix(fmt.Sprintf("cd %s && bundle install", c.zdotdir))
		return s
	}
	if !st.AIServer {
		s.warn("AI integration test skipped (server not running)")
		s.fix("zdots-ctl up")
		return s
	}
	if _, rc := runCmdOut(90*time.Second, "zdots-ruby", llamaTest, "--quick"); rc == 0 {
		s.pass("AI integration  chat (RubyLLM) + embeddings (embed server) verified")
	} else {
		s.fail("AI integration  RubyLLM × llama.cpp test failed")
		s.fix(fmt.Sprintf("zdots-ruby %s/tests/llama_integration.rb  (full output)", c.zdotdir))
	}
	return s
}

func chkOTel(c cfg, st ctlstatus.Status) chkSection {
	var s chkSection
	s.info("OTel pipeline")
	if !st.OTelCollector {
		s.warn("OTLP pipeline  skipped (collector not running)")
		s.fix("zdots-ctl up")
		return s
	}
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Post(c.otlpEndpoint+"/v1/traces", "application/json", strings.NewReader(`{"resourceSpans":[]}`))
	if err == nil {
		_ = resp.Body.Close()
		if resp.StatusCode == 200 {
			s.pass(fmt.Sprintf("OTLP endpoint  accepting spans (%s/v1/traces)", c.otlpEndpoint))
			return s
		}
		s.warn(fmt.Sprintf("OTLP endpoint  responded %d (expected 200)", resp.StatusCode))
		s.fix("otel-collector logs  — check for pipeline errors")
		return s
	}
	addr := strings.TrimPrefix(strings.TrimPrefix(c.otlpEndpoint, "http://"), "https://")
	if conn, err := net.DialTimeout("tcp", addr, 500*time.Millisecond); err == nil {
		_ = conn.Close()
		s.pass(fmt.Sprintf("OTLP endpoint  listening on loopback (%s)", c.otlpEndpoint))
	} else {
		s.warn("OTLP endpoint  responded 000 (expected 200)")
		s.fix("otel-collector logs  — check for pipeline errors")
	}
	return s
}

func chkTraces(c cfg) chkSection {
	var s chkSection
	s.info("Shell traces")
	traceFile := filepath.Join(c.xdgState, "zsh", "traces.jsonl")
	if data, err := os.ReadFile(traceFile); err == nil {
		lines := bytes.Count(data, []byte{'\n'})
		s.pass(fmt.Sprintf("trace file  %s (%d entries)", traceFile, lines))
	} else {
		s.warn("trace file  not found: " + traceFile)
		s.fix("open a new shell session to start tracing")
	}
	return s
}

func chkProvenance(c cfg) chkSection {
	var s chkSection
	s.info("PHI audit log")
	out, _ := runCmdOut(4*time.Second, "log", "show", "--predicate", `subsystem == "com.zdots"`, "--last", "24h", "--style", "compact")
	last := ""
	for _, ln := range strings.Split(out, "\n") {
		ln = strings.TrimSpace(ln)
		if ln != "" && !strings.HasPrefix(ln, "Filtering") {
			last = ln
		}
	}
	if last != "" {
		if len(last) > 80 {
			last = last[:80]
		}
		s.pass(fmt.Sprintf("unified log  entries present (last: %s...)", last))
	} else {
		s.warn("unified log  no com.zdots entries in last 24h (expected after shell activity)")
		s.fix(`log show --predicate 'subsystem == "com.zdots"' --last 24h`)
	}

	manifest := filepath.Join(c.zdotdir, "lib", "llama-models.sha256")
	if data, err := os.ReadFile(manifest); err == nil {
		s.info("\nModel provenance")
		xdgData := envOr("XDG_DATA_HOME", filepath.Join(c.home, ".local", "share"))
		modelsDir := envOr("ZDOTS_AI_MODELS_DIR", filepath.Join(xdgData, "llama-cpp", "models"))
		for _, ln := range strings.Split(string(data), "\n") {
			ln = strings.TrimSpace(ln)
			if ln == "" || strings.HasPrefix(ln, "#") {
				continue
			}
			fields := strings.Fields(ln)
			if len(fields) < 2 {
				continue
			}
			wantHash, fname := fields[0], fields[1]
			fpath := filepath.Join(modelsDir, fname)
			if fileExists(fpath) {
				if gotHash, err := sha256File(fpath); err == nil && gotHash == wantHash {
					s.pass(fmt.Sprintf("model  %s hash OK", fname))
				} else {
					s.fail(fmt.Sprintf("model  %s SHA256 MISMATCH", fname))
				}
			} else {
				s.info(fmt.Sprintf("  [----] model  %s not downloaded", fname))
			}
		}
	}
	return s
}

func chkWorkSecurity(c cfg) chkSection {
	var s chkSection
	s.info("macOS security posture (ZDOTS_CONTEXT=work)")
	if out, rc := runCmdOut(3*time.Second, "fdesetup", "status"); rc == 0 && strings.Contains(out, "FileVault is On") {
		s.pass("FileVault  enabled")
	} else {
		s.fail("FileVault  NOT enabled — required for PHI work")
		s.fix("sudo fdesetup enable")
	}
	if out, rc := runCmdOut(3*time.Second, "csrutil", "status"); rc == 0 && strings.Contains(out, "enabled") {
		s.pass("SIP  enabled")
	} else {
		s.fail("SIP  NOT enabled — required for PHI work")
		s.fix("Boot to Recovery OS and run: csrutil enable")
	}
	if fileExists(filepath.Join(c.zdotdir, ".zdots.secrets")) {
		s.warn("Secrets file  .zdots.secrets still present — run: zdots-keychain migrate && zdots-keychain verify, then delete the file")
	} else {
		s.pass("Secrets file  absent (Keychain-only mode)")
	}
	if k := os.Getenv("ZDOTS_DB_ENCRYPTION_KEY"); k != "" {
		s.pass(fmt.Sprintf("DB encryption key  present (%d chars)", len(k)))
	} else {
		s.fail("DB encryption key  ZDOTS_DB_ENCRYPTION_KEY not set — run: zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>")
	}
	return s
}

func sha256File(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer func() { _ = f.Close() }()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func svcRegistered(c cfg, label string) bool {
	if strings.HasPrefix(label, "com.zdots.") {
		if fileExists(filepath.Join(c.home, "Library", "LaunchAgents", label+".plist")) {
			return true
		}
	}
	out, rc := runCmdOut(2*time.Second, "launchctl", "list")
	if rc == 0 && strings.Contains(out, label) {
		return true
	}
	return false
}

func launchdRunning(label string) bool {
	out, rc := runCmdOut(2*time.Second, "launchctl", "list")
	if rc != 0 {
		return false
	}
	for _, ln := range strings.Split(out, "\n") {
		fields := strings.Fields(ln)
		if len(fields) >= 3 && fields[2] == label {
			_, err := strconv.Atoi(fields[0])
			return err == nil
		}
	}
	return false
}

func runBin(c cfg, name string, args ...string) error {
	p := filepath.Join(c.binDir, name)
	cmd := exec.Command(p, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runBinQuiet(c cfg, name string, args ...string) error {
	p := filepath.Join(c.binDir, name)
	cmd := exec.Command(p, args...)
	return cmd.Run()
}

func waitFor(label, url string, timeoutSec int) bool {
	fmt.Fprintf(os.Stderr, "zdots-ctl: waiting for %s", label)
	for elapsed := 0; elapsed < timeoutSec; elapsed += 3 {
		if httpOK(url, 2*time.Second) {
			fmt.Fprintln(os.Stderr, " ready")
			return true
		}
		fmt.Fprint(os.Stderr, ".")
		time.Sleep(3 * time.Second)
	}
	fmt.Fprintln(os.Stderr)
	fmt.Fprintf(os.Stderr, "zdots-ctl: [err] timed out after %ds waiting for %s (%s)\n", timeoutSec, label, url)
	return false
}

func waitForSoft(url string, timeoutSec int) bool {
	for elapsed := 0; elapsed < timeoutSec; elapsed += 3 {
		if httpOK(url, 2*time.Second) {
			return true
		}
		time.Sleep(3 * time.Second)
	}
	return false
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

func nginxServerHeader(timeout time.Duration) string {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Head("http://127.0.0.1")
	if err != nil {
		return ""
	}
	_ = resp.Body.Close()
	return resp.Header.Get("Server")
}

func appendTraceLog(xdgState, eventType, data string) {
	dir := filepath.Join(xdgState, "zsh")
	_ = os.MkdirAll(dir, 0o700)
	traceFile := filepath.Join(dir, "traces.jsonl")
	f, err := os.OpenFile(traceFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return
	}
	defer func() { _ = f.Close() }()

	pid := os.Getpid()
	sid := envOr("ZDOTS_TRACE_ID", fmt.Sprintf("session-%d", pid))
	spid := envOr("ZDOTS_SPAN_ID", fmt.Sprintf("span-%d", pid))
	ts := time.Now().Format("2006-01-02T15:04:05-0700")
	escaped := strings.ReplaceAll(data, `"`, `\"`)
	_, _ = fmt.Fprintf(f, `{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}`+"\n",
		ts, sid, spid, eventType, escaped)
}

func runCmdOut(timeout time.Duration, name string, args ...string) (string, int) {
	return runCmdEnvOut(timeout, nil, name, args...)
}

func runCmdEnvOut(timeout time.Duration, extraEnv []string, name string, args ...string) (string, int) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	if len(extraEnv) > 0 {
		cmd.Env = append(os.Environ(), extraEnv...)
	}
	out, err := cmd.CombinedOutput()
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
