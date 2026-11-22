package capabilities

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/storage"
)

const (
	bold   = "\033[1m"
	green  = "\033[0;32m"
	red    = "\033[0;31m"
	cyan   = "\033[0;36m"
	yellow = "\033[0;33m"
	reset  = "\033[0m"
)

func usage() string {
	return `Usage: capabilities [--json] [-h|--help]

Environment health and service contract validator.
Checks service providers, critical paths, observability, Knowledge Layer,
deploy diagnostics, and tooling reality against the .zdots.env manifest.
Reports the shared Astronomicon epoch and the independent my structure contract.

Options:
  --json      Machine-readable JSON output
  -h, --help  Show this help
`
}

// Run executes the capabilities command and returns the process exit code.
func Run(args []string) int {
	outputFormat := "text"
	for _, arg := range args {
		switch arg {
		case "--json":
			outputFormat = "json"
		case "-h", "--help":
			fmt.Print(usage())
			return 0
		default:
			fmt.Fprintf(os.Stderr, "capabilities: unknown option: %s\n", arg)
			fmt.Fprint(os.Stderr, usage())
			return 1
		}
	}

	tr := otel.New("capabilities")
	rootSpan := tr.Start("platform.health", nil)
	rootSpan.SetAttr("output_format", outputFormat)

	home, _ := os.UserHomeDir()
	zdotdir := os.Getenv("ZDOTDIR")
	if zdotdir == "" && home != "" {
		zdotdir = filepath.Join(home, ".config", "zsh")
	}

	envMap := loadEnvWithManifest(filepath.Join(zdotdir, ".zdots.env"))
	getEnv := func(key, fallback string) string {
		if v, ok := envMap[key]; ok && v != "" {
			return v
		}
		return fallback
	}

	if zdotdir == "" {
		if cwd, err := os.Getwd(); err == nil {
			zdotdir = cwd
		}
	}
	xdgConfig := getEnv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	xdgState := getEnv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	stateZshDir := filepath.Join(xdgState, "zsh")

	platformVersion := readTrimmedOr(filepath.Join(zdotdir, "VERSION"), "unknown")

	// Parallel external probes.
	var (
		diskAvail  = "unknown"
		o2Live     = 0
		jaegerLive = 0
		aiLive     = 0
		ctxLive    = 0
		ctxDB      = "unknown"
		ctxPending = 0
		storageRaw = json.RawMessage(`{}`)
		colimaRes  colimaStatus
		hasColima  bool
	)

	var wg sync.WaitGroup

	// 1. df -h /
	wg.Add(1)
	go func() {
		defer wg.Done()
		out := runCmd(2*time.Second, "df", "-h", "/")
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) >= 2 {
			fields := strings.Fields(lines[1])
			if len(fields) >= 4 {
				diskAvail = fields[3]
			}
		}
	}()

	// 3. OpenObserve /healthz (legacy) & Jaeger UI /
	o2URL := getEnv("ZDOTS_O2_ENDPOINT", fmt.Sprintf("http://%s:%s", getEnv("ZDOTS_O2_HOST", "127.0.0.1"), getEnv("ZDOTS_O2_PORT", "5080")))
	jaegerURL := getEnv("ZDOTS_JAEGER_ENDPOINT", fmt.Sprintf("http://%s:%s", getEnv("ZDOTS_JAEGER_HOST", "127.0.0.1"), getEnv("ZDOTS_JAEGER_UI_PORT", "16686")))
	wg.Add(1)
	go func() {
		defer wg.Done()
		if httpOK(o2URL+"/healthz", 2*time.Second) {
			o2Live = 1
		}
	}()
	wg.Add(1)
	go func() {
		defer wg.Done()
		if httpOK(jaegerURL+"/", 2*time.Second) {
			jaegerLive = 1
		}
	}()

	// 4. AI /health (if enabled)
	serviceAI := getEnv("ZDOTS_SERVICE_AI", "")
	if serviceAI != "" && serviceAI != "none" {
		aiEndpoint := getEnv("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:11500")
		wg.Add(1)
		go func() {
			defer wg.Done()
			if httpOK(aiEndpoint+"/health", 2*time.Second) {
				aiLive = 1
			}
		}()
	}

	// 5. zdots-ctx status --json
	binCtx := filepath.Join(zdotdir, "bin", "zdots-ctx")
	if isExecFile(binCtx) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			out := runCmd(5*time.Second, binCtx, "status", "--json")
			if len(out) == 0 {
				return
			}
			var st struct {
				Connected   bool   `json:"connected"`
				Database    string `json:"database"`
				PendingJobs int    `json:"pending_jobs"`
			}
			if json.Unmarshal(out, &st) == nil && st.Connected {
				ctxLive = 1
				if st.Database != "" {
					ctxDB = st.Database
				}
				ctxPending = st.PendingJobs
			}
		}()
	}

	// 6. storage collection in-process (only needed for JSON output)
	if outputFormat == "json" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			reserveGB := int64(45)
			if rStr := getEnv("ZDOTS_STORAGE_RESERVE_GB", ""); rStr != "" {
				if parsed, err := strconv.ParseInt(rStr, 10, 64); err == nil && parsed >= 0 {
					reserveGB = parsed
				}
			}
			vaultRoot := getEnv("ZDOTS_VAULT_ROOT", os.Getenv("ZDOTS_MY_ROOT"))
			rep := storage.Collect(home, zdotdir, vaultRoot, reserveGB)
			if b, err := json.Marshal(rep); err == nil {
				storageRaw = json.RawMessage(b)
			}
		}()
	}

	// 7. colima-status --json (only needed for text output)
	colimaBin := filepath.Join(zdotdir, "bin", "colima-status")
	if outputFormat == "text" && isExecFile(colimaBin) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			out := runCmd(3*time.Second, colimaBin, "--json")
			hasColima = true
			_ = json.Unmarshal(out, &colimaRes)
		}()
	}

	// Fast local checks while goroutines run.
	type svcCheck struct {
		name     string
		provider string
		ok       bool
		missing  string
	}
	services := []struct {
		name string
		dir  string
	}{
		{"PKG_MANAGER", "pkg"},
		{"NODE_RUNTIME", "node"},
		{"TRACE", "trace"},
		{"AI", "ai"},
		{"WHISPER", "ai"},
	}

	errors := 0
	svcResults := make([]svcCheck, 0, len(services))
	for _, s := range services {
		prov := getEnv("ZDOTS_SERVICE_"+s.name, "none")
		rel := filepath.Join("providers", s.dir, prov+".zsh")
		full := filepath.Join(zdotdir, rel)
		ok := prov == "none" || isRegularFile(full)
		if !ok {
			errors++
		}
		svcResults = append(svcResults, svcCheck{
			name:     s.name,
			provider: prov,
			ok:       ok,
			missing:  rel,
		})
	}

	diagCmd := filepath.Join(zdotdir, "bin", "zdots-log-analyze")
	diagAvailable := 0
	if isExecFile(diagCmd) {
		diagAvailable = 1
	}
	latestUpdateLog := latestGlob(filepath.Join(stateZshDir, "zdots-update-local-*.log"))

	traceFile := filepath.Join(stateZshDir, "traces.jsonl")
	traceExists := isRegularFile(traceFile)
	lastTraceTS := "unknown"
	traceAgeSeconds := "unknown"
	if traceExists {
		lastTraceTS, traceAgeSeconds = readLastTraceTS(traceFile)
	}

	mcpLlama := 0
	if isExecFile(filepath.Join(zdotdir, "bin", "llama-mcp")) {
		mcpLlama = 1
	} else if outputFormat == "text" {
		errors++
	}
	mcpCtx := 0
	if isExecFile(filepath.Join(zdotdir, "bin", "ctx-mcp")) {
		mcpCtx = 1
	} else if outputFormat == "text" {
		errors++
	}

	stdinTTY := isTTY(os.Stdin)
	stdoutTTY := isTTY(os.Stdout)
	stderrTTY := isTTY(os.Stderr)
	termVal := getEnv("TERM", "unset")
	termProg := getEnv("TERM_PROGRAM", "unset")
	mux := detectMux(getEnv("TMUX", ""), getEnv("TERM", ""))
	lines := getEnv("LINES", "?")
	cols := getEnv("COLUMNS", "?")

	wg.Wait()

	unameOS := osName()
	unameArch := archName()

	if outputFormat == "text" {
		fmt.Printf("%sZdots Environment Capabilities Report%s\n", bold, reset)
		fmt.Println("----------------------------------------")
		fmt.Printf("%sPlatform:%s    %s%s%s  (zdots · adots · vdots)\n",
			cyan, reset, bold, platformVersion, reset)
		fmt.Printf("%sSession ID:%s  %s\n", cyan, reset, getEnv("ZDOTS_SESSION_ID", "<unset>"))
		fmt.Printf("%sProfile:%s     %s\n", cyan, reset, getEnv("ZDOTS_ENV_PROFILE", "unknown"))
		fmt.Printf("%sOS:%s          %s (%s)\n", cyan, reset, unameOS, unameArch)
		fmt.Printf("%sCI/ACT:%s      %s / %s\n", cyan, reset, getEnv("ACT", "false"), getEnv("CI", "false"))

		fmt.Println("")
		fmt.Printf("%sContainer Runtime (Colima / Docker):%s\n", bold, reset)
		if hasColima {
			if colimaRes.Healthy {
				fmt.Printf("  %-15s : %srunning/healthy%s\n", "state", green, reset)
			} else {
				fmt.Printf("  %-15s : %sstopped/unhealthy%s\n", "state", yellow, reset)
			}
			sock := colimaRes.Socket
			if sock == "" {
				sock = "(unknown)"
			}
			fmt.Printf("  %-15s : %s\n", "socket", sock)
			if colimaRes.SocketExists {
				fmt.Printf("  %-15s : %spresent%s\n", "socket status", green, reset)
			} else {
				fmt.Printf("  %-15s : %smissing%s\n", "socket status", yellow, reset)
			}
			fmt.Printf("  %-15s : %s\n", "interface", "colima-status --json  |  colima-status socket  |  colima-status health")
		} else {
			fmt.Printf("  %-15s : %smissing%s\n", "colima-status", yellow, reset)
		}

		fmt.Println("")
		fmt.Printf("%sService Composition:%s\n", bold, reset)
		for _, s := range svcResults {
			var st string
			if s.provider == "none" {
				st = fmt.Sprintf("%s∅ none%s", yellow, reset)
			} else if s.ok {
				st = fmt.Sprintf("%s✓ %s%s", green, s.provider, reset)
			} else {
				st = fmt.Sprintf("%s✗ %s (missing provider file: %s)%s", red, s.provider, s.missing, reset)
			}
			fmt.Printf("  %-15s : %s\n", s.name, st)
		}

		fmt.Println("")
		fmt.Printf("%sCritical Paths:%s\n", bold, reset)
		critPaths := []struct{ label, val string }{
			{"ZDOTDIR", zdotdir},
			{"XDG_CONFIG_HOME", xdgConfig},
			{"XDG_STATE_HOME", xdgState},
			{"HOMEBREW_PREFIX", getEnv("HOMEBREW_PREFIX", "<unset>")},
		}
		for _, cp := range critPaths {
			pStatus := fmt.Sprintf("%smissing%s", yellow, reset)
			if isDir(cp.val) {
				pStatus = fmt.Sprintf("%sexists%s", green, reset)
			}
			fmt.Printf("  %-15s : %-20s [%s]\n", cp.label, cp.val, pStatus)
		}
		fmt.Printf("  %sDisk Available:%s  %s\n", cyan, reset, diskAvail)

		fmt.Println("")
		fmt.Printf("%sTerminal State:%s\n", bold, reset)
		fmt.Printf("  %-15s : %s\n", "stdin TTY", yesNo(stdinTTY))
		fmt.Printf("  %-15s : %s\n", "stdout TTY", yesNo(stdoutTTY))
		fmt.Printf("  %-15s : %s\n", "stderr TTY", yesNo(stderrTTY))
		fmt.Printf("  %-15s : %s%s%s\n", "TERM", cyan, termVal, reset)
		fmt.Printf("  %-15s : %s%s%s\n", "TERM_PROGRAM", cyan, termProg, reset)
		fmt.Printf("  %-15s : %s%s%s\n", "Multiplexer", cyan, mux, reset)
		fmt.Printf("  %-15s : %s%sx%s%s\n", "Dimensions", cyan, lines, cols, reset)

		fmt.Println("")
		fmt.Printf("%sDeploy Diagnostics:%s\n", bold, reset)
		if diagAvailable == 1 {
			fmt.Printf("  %-15s : %s%s%s\n", "log analyzer", green, diagCmd, reset)
			fmt.Printf("  %-15s : %s\n", "log dir", stateZshDir)
			if latestUpdateLog != "" {
				fmt.Printf("  %-15s : %s\n", "latest update", latestUpdateLog)
			}
		} else {
			fmt.Printf("  %-15s : %smissing%s\n", "log analyzer", yellow, reset)
		}

		fmt.Println("")
		fmt.Printf("%sObservability Health:%s\n", bold, reset)
		if traceExists {
			fmt.Printf("  %sTrace File:%s   %s [%sexists%s]\n", cyan, reset, traceFile, green, reset)
			fmt.Printf("  %sLast Trace:%s   %s\n", cyan, reset, lastTraceTS)
			fmt.Printf("  %sTrace Age:%s    %s seconds\n", cyan, reset, traceAgeSeconds)
		} else {
			fmt.Printf("  %sTrace File:%s   %s [%smissing%s]\n", cyan, reset, traceFile, yellow, reset)
		}
		if jaegerLive == 1 {
			fmt.Printf("  %sJaeger:%s        %sonline%s (%s)\n", cyan, reset, green, reset, jaegerURL)
		} else {
			fmt.Printf("  %sJaeger:%s        %soffline%s\n", cyan, reset, yellow, reset)
		}
		if serviceAI != "" && serviceAI != "none" {
			fmt.Printf("  %sAI Service:%s    %s [model: %s]\n", cyan, reset, serviceAI, getEnv("ZDOTS_AI_MODEL", "unknown"))
			if aiLive == 1 {
				fmt.Printf("  %sAI Server:%s     %sonline%s\n", cyan, reset, green, reset)
			} else {
				fmt.Printf("  %sAI Server:%s     %soffline/unavailable%s\n", cyan, reset, yellow, reset)
			}
		}

		fmt.Println("")
		fmt.Printf("%sKnowledge Layer:%s\n", bold, reset)
		if ctxLive == 1 {
			fmt.Printf("  %sKnowledge DB:%s  %sonline (%s) [%d pending jobs]%s\n", cyan, reset, green, ctxDB, ctxPending, reset)
		} else {
			fmt.Printf("  %sKnowledge DB:%s  %soffline/uninitialized%s\n", cyan, reset, yellow, reset)
		}
		if mcpLlama == 1 {
			fmt.Printf("  %-15s : %sonline%s\n", "mcp:llama-mcp", green, reset)
		} else {
			fmt.Printf("  %-15s : %smissing/not executable%s\n", "mcp:llama-mcp", red, reset)
		}
		if mcpCtx == 1 {
			fmt.Printf("  %-15s : %sonline%s\n", "mcp:ctx-mcp", green, reset)
		} else {
			fmt.Printf("  %-15s : %smissing/not executable%s\n", "mcp:ctx-mcp", red, reset)
		}

		fmt.Println("")
		fmt.Printf("%sTooling Reality:%s\n", bold, reset)
		for _, tool := range []string{"zsh", "git", "brew", "mise", "node", "npm", "python3"} {
			if p, err := exec.LookPath(tool); err == nil {
				fmt.Printf("  %-15s : %s%s%s\n", tool, green, p, reset)
			} else {
				fmt.Printf("  %-15s : %snot found%s\n", tool, yellow, reset)
			}
		}
		fmt.Println("----------------------------------------")
	} else {
		payload := reportJSON{
			SessionID: getEnv("ZDOTS_SESSION_ID", ""),
			Platform: platformInfo{
				Version:           platformVersion,
				Scheme:            "imperial-calver",
				VersionedSurfaces: loadSurfaces(xdgConfig),
			},
			Profile:             getEnv("ZDOTS_ENV_PROFILE", "unknown"),
			OS:                  unameOS,
			Arch:                unameArch,
			DiskAvailable:       diskAvail,
			DiskAvailableSource: "df -h / Avail",
			Storage:             storageRaw,
			Terminal: terminalInfo{
				StdinTTY:    stdinTTY,
				StdoutTTY:   stdoutTTY,
				StderrTTY:   stderrTTY,
				Term:        termVal,
				TermProgram: termProg,
				Multiplexer: mux,
				Dimensions:  lines + "x" + cols,
			},
			AI: aiInfo{
				Status: aiLive,
				Model:  getEnv("ZDOTS_AI_MODEL", "unknown"),
			},
			Observability: obsInfo{
				TraceFile:           traceFile,
				LastTrace:           lastTraceTS,
				LastTraceAgeSeconds: traceAgeSeconds,
				Jaeger:              jaegerLive,
				OpenObserve:         o2Live,
			},
			Diagnostics: diagInfo{
				LogAnalyzer:      diagAvailable,
				LogDir:           stateZshDir,
				LatestUpdateLog:  latestUpdateLog,
				AnalyzeUpdate:    "zdots-log-analyze update",
				AnalyzeBootstrap: "zdots-log-analyze bootstrap",
				AnalyzeUpgrade:   "zdots-log-analyze upgrade",
			},
			Brain: brainInfo{
				IntelligenceLive:    ctxLive,
				IntelligenceDB:      ctxDB,
				IntelligencePending: ctxPending,
				MCPLlama:            mcpLlama,
				MCPCtx:              mcpCtx,
			},
			HealthErrors: errors,
		}
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(payload)
	}

	// Self-reporting (native OTLP/HTTP JSON), bounded timeout.
	rootSpan.SetAttr("profile", getEnv("ZDOTS_ENV_PROFILE", "unknown"))
	rootSpan.SetAttr("os", unameOS)
	rootSpan.SetAttr("disk.avail", diskAvail)
	rootSpan.SetAttr("ai.status", aiLive)
	rootSpan.SetAttr("health_errors", errors)
	if errors == 0 {
		rootSpan.End(true, "")
	} else {
		rootSpan.End(false, fmt.Sprintf("%d service contract violation(s)", errors))
	}
	tr.Flush(250 * time.Millisecond)

	if errors > 0 {
		if outputFormat == "text" {
			fmt.Printf("%sHealth Check Failed: %d service contract violation(s) detected.%s\n", red, errors, reset)
		}
		return 1
	}
	if outputFormat == "text" {
		fmt.Printf("%sHealth Check Passed: Service contract is valid.%s\n", green, reset)
	}
	return 0
}

type colimaStatus struct {
	Healthy      bool   `json:"healthy"`
	Socket       string `json:"socket"`
	SocketExists bool   `json:"socket_exists"`
}

type reportJSON struct {
	SessionID           string          `json:"session_id"`
	Platform            platformInfo    `json:"platform"`
	Profile             string          `json:"profile"`
	OS                  string          `json:"os"`
	Arch                string          `json:"arch"`
	DiskAvailable       string          `json:"disk_available"`
	DiskAvailableSource string          `json:"disk_available_source"`
	Storage             json.RawMessage `json:"storage"`
	Terminal            terminalInfo    `json:"terminal"`
	AI                  aiInfo          `json:"ai"`
	Observability       obsInfo         `json:"observability"`
	Diagnostics         diagInfo        `json:"diagnostics"`
	Brain               brainInfo       `json:"brain"`
	HealthErrors        int             `json:"health_errors"`
}

type platformInfo struct {
	Version           string   `json:"version"`
	Scheme            string   `json:"scheme"`
	VersionedSurfaces []string `json:"versioned_surfaces"`
}

func loadSurfaces(xdgConfig string) []string {
	manifest := os.Getenv("ZDOTS_SURFACES_FILE")
	if manifest == "" {
		manifest = filepath.Join(xdgConfig, "adots", "surfaces.conf")
	}
	b, err := os.ReadFile(manifest)
	if err != nil {
		return []string{"zdots", "adots", "vdots"}
	}
	var out []string
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) >= 1 && strings.TrimSpace(fields[0]) != "" {
			out = append(out, strings.TrimSpace(fields[0]))
		}
	}
	if len(out) == 0 {
		return []string{"zdots", "adots", "vdots"}
	}
	return out
}

type terminalInfo struct {
	StdinTTY    bool   `json:"stdin_tty"`
	StdoutTTY   bool   `json:"stdout_tty"`
	StderrTTY   bool   `json:"stderr_tty"`
	Term        string `json:"term"`
	TermProgram string `json:"term_program"`
	Multiplexer string `json:"multiplexer"`
	Dimensions  string `json:"dimensions"`
}

type aiInfo struct {
	Status int    `json:"status"`
	Model  string `json:"model"`
}

type obsInfo struct {
	TraceFile           string `json:"trace_file"`
	LastTrace           string `json:"last_trace"`
	LastTraceAgeSeconds string `json:"last_trace_age_seconds"`
	Jaeger              int    `json:"jaeger"`
	OpenObserve         int    `json:"openobserve"`
}

type diagInfo struct {
	LogAnalyzer      int    `json:"log_analyzer"`
	LogDir           string `json:"log_dir"`
	LatestUpdateLog  string `json:"latest_update_log"`
	AnalyzeUpdate    string `json:"analyze_update"`
	AnalyzeBootstrap string `json:"analyze_bootstrap"`
	AnalyzeUpgrade   string `json:"analyze_upgrade"`
}

type brainInfo struct {
	IntelligenceLive    int    `json:"intelligence_live"`
	IntelligenceDB      string `json:"intelligence_db"`
	IntelligencePending int    `json:"intelligence_pending"`
	MCPLlama            int    `json:"mcp_llama"`
	MCPCtx              int    `json:"mcp_ctx"`
}

// loadEnvWithManifest reads os.Environ() and fills in keys it lacks from the
// top-level KEY=VALUE / export KEY=VALUE lines of manifestPath. The shell has
// usually sourced .zdots.env already, so exported values win. Lines inside
// if/case blocks are skipped (their conditions need a shell), ${NAME:-default}
// resolves like the shell, and other expansions are left out rather than
// copied through as literal text.
func loadEnvWithManifest(manifestPath string) map[string]string {
	m := make(map[string]string)
	for _, e := range os.Environ() {
		if k, v, ok := strings.Cut(e, "="); ok {
			m[k] = v
		}
	}
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return m
	}
	depth := 0
	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		switch word, _, _ := strings.Cut(line, " "); strings.TrimSuffix(word, ";") {
		case "if", "case":
			depth++
			continue
		case "fi", "esac":
			if depth > 0 {
				depth--
			}
			continue
		}
		if depth > 0 {
			continue
		}
		line = strings.TrimPrefix(line, "export ")
		line = strings.TrimSpace(line)
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(v)
		if len(v) >= 2 && ((v[0] == '"' && v[len(v)-1] == '"') || (v[0] == '\'' && v[len(v)-1] == '\'')) {
			v = v[1 : len(v)-1]
		}
		if sm := manifestDefault.FindStringSubmatch(v); sm != nil {
			v = sm[2]
			if ev := m[sm[1]]; ev != "" {
				v = ev
			}
		} else if strings.ContainsAny(v, "$`") {
			continue
		}
		if k != "" && m[k] == "" {
			m[k] = v
		}
	}
	return m
}

// manifestDefault matches a whole ${NAME:-literal} value.
var manifestDefault = regexp.MustCompile(`^\$\{([A-Za-z_][A-Za-z0-9_]*):-([^$` + "`" + `}]*)\}$`)

func runCmd(timeout time.Duration, name string, args ...string) []byte {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	out, _ := cmd.Output()
	return out
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

func readTrimmedOr(path, fallback string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return fallback
	}
	s := strings.TrimSpace(string(b))
	if s == "" {
		return fallback
	}
	return s
}

func readLastTraceTS(path string) (string, string) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "unknown", "unknown"
	}
	trimmed := bytes.TrimRight(b, "\r\n")
	if len(trimmed) == 0 {
		return "unknown", "unknown"
	}
	idx := bytes.LastIndexByte(trimmed, '\n')
	lastLine := trimmed
	if idx >= 0 {
		lastLine = trimmed[idx+1:]
	}
	var obj struct {
		TS string `json:"ts"`
	}
	if json.Unmarshal(lastLine, &obj) != nil || obj.TS == "" {
		return "unknown", "unknown"
	}
	if t, err := time.Parse("2006-01-02T15:04:05-0700", obj.TS); err == nil {
		return obj.TS, strconv.FormatInt(int64(time.Since(t).Seconds()), 10)
	}
	if t, err := time.Parse(time.RFC3339, obj.TS); err == nil {
		return obj.TS, strconv.FormatInt(int64(time.Since(t).Seconds()), 10)
	}
	return obj.TS, "unknown"
}

func latestGlob(pattern string) string {
	matches, err := filepath.Glob(pattern)
	if err != nil || len(matches) == 0 {
		return ""
	}
	type entry struct {
		path  string
		mtime time.Time
	}
	entries := make([]entry, 0, len(matches))
	for _, m := range matches {
		if info, err := os.Stat(m); err == nil {
			entries = append(entries, entry{path: m, mtime: info.ModTime()})
		}
	}
	if len(entries) == 0 {
		return ""
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].mtime.After(entries[j].mtime)
	})
	return entries[0].path
}

func isRegularFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func isExecFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir() && (info.Mode()&0o111) != 0
}

func isTTY(f *os.File) bool {
	info, err := f.Stat()
	return err == nil && (info.Mode()&os.ModeCharDevice) != 0
}

func detectMux(tmuxEnv, termEnv string) string {
	if tmuxEnv != "" {
		return "tmux"
	}
	if strings.HasPrefix(termEnv, "screen") || strings.HasPrefix(termEnv, "tmux") {
		return "screen/tmux"
	}
	return "none"
}

func yesNo(b bool) string {
	if b {
		return green + "yes" + reset
	}
	return yellow + "no" + reset
}

func osName() string {
	switch runtime.GOOS {
	case "darwin":
		return "Darwin"
	case "linux":
		return "Linux"
	default:
		return runtime.GOOS
	}
}

func archName() string {
	switch runtime.GOARCH {
	case "arm64":
		return "arm64"
	case "amd64":
		return "x86_64"
	default:
		return runtime.GOARCH
	}
}
