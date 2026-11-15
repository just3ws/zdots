package status

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	reset  = "\033[0m"
	bold   = "\033[1m"
	dim    = "\033[2m"
	green  = "\033[0;32m"
	red    = "\033[0;31m"
	yellow = "\033[0;33m"
	cyan   = "\033[0;36m"
)

func usage() string {
	return `bin/zdots-status — Live TUI dashboard for Zdots platform health.

Paints a self-refreshing panel in the alternate screen showing service
status, shell environment, home-dir warnings, and storage at a glance.

Usage: zdots-status [--once] [--interval N]
  --once        Draw once and exit (no live refresh)
  --interval N  Refresh every N seconds (default: 5)
  -h, --help    Show this help
`
}

type state struct {
	zdotdir    string
	home       string
	xdgState   string
	aiEndpoint string
	o2URL      string

	// services
	aiUp     bool
	aiModel  string
	otelUp   bool
	colimaUp bool
	o2Up     bool

	// storage (cached 60s)
	diskTS     time.Time
	modelDisk  string
	modelCount int
	dockerDisk string

	// home warnings
	homeWarnings []string

	// phi
	phiAIMode         string
	phiHistoryRedact  string
	phiCaptureEnabled string
	phiKeychainCount  int

	// utilization
	utilTasks24h  int
	utilAI24h     int
	utilChecks24h int

	// db
	dbUp     bool
	dbStatus string

	// tasks
	activeTask    string
	taskWIPCount  int
	taskTodoCount int

	// shell
	startupMS string
}

// Run executes the zdots-status command and returns the process exit code.
func Run(args []string) int {
	once := false
	interval := 5

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--once":
			once = true
		case arg == "--interval":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "zdots-status: --interval requires N")
				return 1
			}
			i++
			n, err := strconv.Atoi(args[i])
			if err != nil || n < 1 {
				fmt.Fprintf(os.Stderr, "zdots-status: invalid interval: %s\n", args[i])
				return 1
			}
			interval = n
		case strings.HasPrefix(arg, "--interval="):
			val := strings.TrimPrefix(arg, "--interval=")
			n, err := strconv.Atoi(val)
			if err != nil || n < 1 {
				fmt.Fprintf(os.Stderr, "zdots-status: invalid interval: %s\n", val)
				return 1
			}
			interval = n
		case arg == "-h" || arg == "--help":
			fmt.Print(usage())
			return 0
		default:
			fmt.Fprintf(os.Stderr, "zdots-status: unknown option: %s\n", arg)
			return 1
		}
	}

	if !hasTputCols() {
		fmt.Fprintln(os.Stderr, "zdots-status: terminal does not support tput — use --once or redirect to a tty")
		once = true
	}

	home, _ := os.UserHomeDir()
	zdotdir := os.Getenv("ZDOTDIR")
	if zdotdir == "" && home != "" {
		zdotdir = filepath.Join(home, ".config", "zsh")
	}
	xdgState := os.Getenv("XDG_STATE_HOME")
	if xdgState == "" && home != "" {
		xdgState = filepath.Join(home, ".local", "state")
	}
	aiEndpoint := os.Getenv("ZDOTS_AI_ENDPOINT")
	if aiEndpoint == "" {
		aiEndpoint = "http://127.0.0.1:11500"
	}

	st := &state{
		zdotdir:    zdotdir,
		home:       home,
		xdgState:   xdgState,
		aiEndpoint: aiEndpoint,
		o2URL:      "http://127.0.0.1:5080",
		aiModel:    "unknown",
	}

	if once || !runTput("smcup") {
		st.probeAll(true)
		st.draw(true, interval)
		return 0
	}

	runTput("civis")
	cleanup := func() {
		_ = exec.Command("tput", "cvvis").Run()
		_ = exec.Command("tput", "rmcup").Run()
	}
	defer cleanup()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	// Initial full probe including shell timing.
	st.probeAll(true)
	_ = exec.Command("tput", "cup", "0", "0").Run()
	st.draw(false, interval)

	keyCh := make(chan byte, 4)
	go readKeys(keyCh)

	ticker := time.NewTicker(time.Duration(interval) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-sigCh:
			return 0
		case k := <-keyCh:
			if k == 'q' || k == 'Q' {
				return 0
			}
			if k == 'r' || k == 'R' {
				st.diskTS = time.Time{}
				st.probeAll(false)
				_ = exec.Command("tput", "cup", "0", "0").Run()
				st.draw(false, interval)
			}
		case <-ticker.C:
			st.probeAll(false)
			_ = exec.Command("tput", "cup", "0", "0").Run()
			st.draw(false, interval)
		}
	}
}

func (s *state) probeAll(includeShell bool) {
	var wg sync.WaitGroup

	// Services + storage (storage depends on colimaUp)
	wg.Add(1)
	go func() {
		defer wg.Done()
		s.probeServices()
		s.probeStorage()
	}()

	wg.Add(1)
	go func() { defer wg.Done(); s.probeHome() }()

	wg.Add(1)
	go func() { defer wg.Done(); s.probePHI() }()

	wg.Add(1)
	go func() { defer wg.Done(); s.probeUtilization() }()

	wg.Add(1)
	go func() { defer wg.Done(); s.probeDB() }()

	wg.Add(1)
	go func() { defer wg.Done(); s.probeTasks() }()

	if includeShell {
		wg.Add(1)
		go func() { defer wg.Done(); s.probeShell() }()
	}

	wg.Wait()
}

func (s *state) probeServices() {
	s.aiUp = false
	s.aiModel = "unknown"
	s.otelUp = false
	s.colimaUp = false
	s.o2Up = false

	ctl := filepath.Join(s.zdotdir, "bin", "zdots-ctl")
	out := runCmd(5*time.Second, ctl, "status", "--json")
	if len(out) == 0 {
		return
	}
	var res struct {
		AIServer      bool   `json:"ai_server"`
		AIModel       string `json:"ai_model"`
		OTelCollector bool   `json:"otel_collector"`
		Colima        bool   `json:"colima"`
		OpenObserve   bool   `json:"openobserve"`
	}
	if json.Unmarshal(out, &res) == nil {
		s.aiUp = res.AIServer
		if res.AIModel != "" {
			s.aiModel = res.AIModel
		}
		s.otelUp = res.OTelCollector
		s.colimaUp = res.Colima
		s.o2Up = res.OpenObserve
	}
}

func (s *state) probeStorage() {
	if !s.diskTS.IsZero() && time.Since(s.diskTS) < 60*time.Second {
		return
	}
	s.diskTS = time.Now()
	s.modelDisk = ""
	s.modelCount = 0
	s.dockerDisk = ""

	if _, err := exec.LookPath("llama-ctl"); err == nil {
		out := runCmd(3*time.Second, "llama-ctl", "config", "--json")
		var cfg struct {
			ModelsDir string `json:"models_dir"`
		}
		if json.Unmarshal(out, &cfg) == nil && cfg.ModelsDir != "" {
			if info, err := os.Stat(cfg.ModelsDir); err == nil && info.IsDir() {
				duOut := runCmd(3*time.Second, "du", "-sh", cfg.ModelsDir)
				if fields := strings.Fields(string(duOut)); len(fields) >= 1 {
					s.modelDisk = fields[0]
				} else {
					s.modelDisk = "?"
				}
				if entries, err := os.ReadDir(cfg.ModelsDir); err == nil {
					for _, e := range entries {
						if !e.IsDir() && strings.HasSuffix(e.Name(), ".gguf") {
							s.modelCount++
						}
					}
				}
			}
		}
	}

	if s.colimaUp {
		if _, err := exec.LookPath("docker"); err == nil {
			out := runCmd(3*time.Second, "docker", "system", "df")
			var imgs, vols string
			for _, line := range strings.Split(string(out), "\n") {
				fields := strings.Fields(line)
				if strings.HasPrefix(line, "Images") && len(fields) >= 4 {
					imgs = fields[3]
				} else if strings.HasPrefix(line, "Local Volumes") && len(fields) >= 4 {
					vols = fields[3]
				}
			}
			if imgs != "" || vols != "" {
				s.dockerDisk = fmt.Sprintf("%s images, %s volumes", imgs, vols)
			} else {
				s.dockerDisk = "unavailable"
			}
		}
	}
}

func (s *state) probeHome() {
	s.homeWarnings = nil
	for _, f := range []string{".zshrc", ".zprofile", ".zlogin", ".zlogout"} {
		p := filepath.Join(s.home, f)
		if info, err := os.Stat(p); err == nil && !info.IsDir() {
			s.homeWarnings = append(s.homeWarnings, p)
		}
	}
}

func (s *state) probePHI() {
	s.phiAIMode = envOr("ZDOTS_AI_MODE", "local")
	s.phiHistoryRedact = envOr("ZDOTS_HISTORY_REDACT", "1")
	s.phiCaptureEnabled = envOr("ZDOTS_CAPTURE_ENABLED", "0")
	s.phiKeychainCount = countZdotsKeychainEntries()
}

func (s *state) probeUtilization() {
	s.utilTasks24h = 0
	s.utilAI24h = 0
	s.utilChecks24h = 0

	traceFile := filepath.Join(s.xdgState, "zsh", "traces.jsonl")
	b, err := os.ReadFile(traceFile)
	if err != nil {
		return
	}
	lines := bytes.Split(bytes.TrimRight(b, "\r\n"), []byte("\n"))
	if len(lines) > 5000 {
		lines = lines[len(lines)-5000:]
	}
	cutoff := time.Now().Add(-24 * time.Hour)
	for _, line := range lines {
		if len(line) == 0 {
			continue
		}
		var obj struct {
			TS string `json:"ts"`
		}
		if json.Unmarshal(line, &obj) != nil || obj.TS == "" {
			continue
		}
		t, err := parseTraceTime(obj.TS)
		if err != nil || t.Before(cutoff) {
			continue
		}
		if bytes.Contains(line, []byte("task_start")) {
			s.utilTasks24h++
		}
		if bytes.Contains(line, []byte("ai_query")) {
			s.utilAI24h++
		}
		if bytes.Contains(line, []byte("platform_check")) {
			s.utilChecks24h++
		}
	}
}

func (s *state) probeDB() {
	s.dbUp = false
	s.dbStatus = ""
	if _, err := exec.LookPath("psql"); err != nil {
		return
	}
	pass := keychainGet("ZDOTS_RO_PASSWORD")

	ctx1, cancel1 := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel1()
	c1 := exec.CommandContext(ctx1, "psql", "-qAt", "-U", "zdots_ro", "-d", "my", "-c", `\q`)
	c1.Env = append(os.Environ(), "PGPASSWORD="+pass)
	if c1.Run() != nil {
		return
	}

	s.dbUp = true
	ctx2, cancel2 := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel2()
	c2 := exec.CommandContext(ctx2, "psql", "-qAt", "--no-psqlrc", "-U", "zdots_ro", "-d", "my",
		"-c", "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
	c2.Env = append(os.Environ(), "PGPASSWORD="+pass, "PGAPPNAME=zdots-status")
	out, err := c2.Output()
	tblCount := "?"
	if err == nil {
		trimmed := strings.TrimSpace(string(out))
		if _, err := strconv.Atoi(trimmed); err == nil {
			tblCount = trimmed
		}
	}
	s.dbStatus = tblCount + " public tables"
}

func (s *state) probeTasks() {
	s.activeTask = ""
	s.taskWIPCount = 0
	s.taskTodoCount = 0

	if b, err := os.ReadFile(filepath.Join(s.xdgState, "zsh", "active_task")); err == nil {
		s.activeTask = strings.TrimSpace(string(b))
	}

	if _, err := exec.LookPath("backlog"); err == nil {
		out := runCmd(3*time.Second, "backlog", "task", "list")
		s.taskWIPCount, s.taskTodoCount = parseBacklogCounts(string(out))
	}
}

func (s *state) probeShell() {
	s.startupMS = ""
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "zsh", "-i", "-c", "exit")
	cmd.Env = append(os.Environ(), "ZDOTDIR="+s.zdotdir, "HOME="+s.home)
	start := time.Now()
	if cmd.Run() == nil {
		ms := time.Since(start).Milliseconds()
		s.startupMS = fmt.Sprintf("%dms", ms)
	}
}

func (s *state) draw(once bool, interval int) {
	cols := termCols()
	now := time.Now().Format("2006-01-02 15:04:05")
	host := shortHostname()

	title := "  zdots-status"
	rhs := fmt.Sprintf("%s  %s  ", host, now)
	gap := cols - len(title) - len(rhs)
	if gap < 1 {
		gap = 1
	}
	fmt.Printf("%s%s%s%s%s%s%s\n", bold, title, reset, strings.Repeat(" ", gap), dim, rhs, reset)
	printRule("═", cols)

	printSection("Services", cols)
	const w = 20
	if s.aiUp {
		fmt.Printf("  %s  %s  %smodel=%s%s  %s%s%s\n",
			tagUp(), field(w, "llama.cpp"), dim, s.aiModel, reset, dim, s.aiEndpoint, reset)
	} else {
		fmt.Printf("  %s  %s  %sllama-ctl start%s\n",
			tagDown(), field(w, "llama.cpp"), dim, reset)
	}
	if s.otelUp {
		fmt.Printf("  %s  %s  %s:4318 (http)  :4317 (grpc)%s\n",
			tagUp(), field(w, "otelcol-contrib"), dim, reset)
	} else {
		fmt.Printf("  %s  %s  %sotel-collector start%s\n",
			tagDown(), field(w, "otelcol-contrib"), dim, reset)
	}
	if s.colimaUp {
		fmt.Printf("  %s  %s\n", tagUp(), field(w, "Colima"))
	} else {
		fmt.Printf("  %s  %s  %s(optional: colima start)%s\n",
			tagDown(), field(w, "Colima"), dim, reset)
	}
	if s.o2Up {
		fmt.Printf("  %s  %s  %s%s%s\n",
			tagUp(), field(w, "OpenObserve"), dim, s.o2URL, reset)
	} else {
		fmt.Printf("  %s  %s  %szsvc start o2%s\n",
			tagDown(), field(w, "OpenObserve"), dim, reset)
	}

	printSection("Shell", cols)
	fmt.Printf("  %s  ZDOTDIR  %s\n", tagPass(), s.zdotdir)
	if s.startupMS != "" {
		const budget = 80
		msVal, _ := strconv.Atoi(strings.TrimSuffix(s.startupMS, "ms"))
		if msVal > budget {
			fmt.Printf("  %s  startup  %s%s%s  (budget %dms)\n", tagWarn(), yellow, s.startupMS, reset, budget)
		} else {
			fmt.Printf("  %s  startup  %s\n", tagPass(), s.startupMS)
		}
	}

	printSection("PHI Boundary", cols)
	aiIcon := tagWarn()
	if s.phiAIMode == "local" {
		aiIcon = tagPass()
	}
	fmt.Printf("  %s  %-20s mode=%s\n", aiIcon, "AI mode", s.phiAIMode)
	if s.phiHistoryRedact == "1" {
		fmt.Printf("  %s  %-20s ZDOTS_HISTORY_REDACT=1\n", tagPass(), "History redact")
	} else {
		fmt.Printf("  %s  %-20s %sZDOTS_HISTORY_REDACT=0  PHI may persist in history%s\n",
			tagWarn(), "History redact", yellow, reset)
	}
	if s.phiCaptureEnabled == "1" {
		fmt.Printf("  %s  %-20s capture enabled\n", tagWarn(), "Context capture")
	} else {
		fmt.Printf("  %s  %-20s capture disabled (opt-in)\n", tagPass(), "Context capture")
	}
	fmt.Printf("  %s  %-20s %d secret(s) in login Keychain\n", tagPass(), "Keychain", s.phiKeychainCount)

	printSection("Utilization (Last 24h)", cols)
	fmt.Printf("  %s  %-20s %d task(s)\n", tagPass(), "Tasks", s.utilTasks24h)
	fmt.Printf("  %s  %-20s %d query(ies)\n", tagPass(), "AI Queries", s.utilAI24h)
	fmt.Printf("  %s  %-20s %d platform check(s)\n", tagPass(), "Health", s.utilChecks24h)

	printSection("Database", cols)
	if s.dbUp {
		fmt.Printf("  %s  %-20s my  (%s)\n", tagPass(), "PostgreSQL", s.dbStatus)
	} else {
		fmt.Printf("  %s  %-20s %spsql -U zdots_ro my%s\n", tagDown(), "PostgreSQL", dim, reset)
	}

	printSection("Tasks", cols)
	if s.activeTask != "" {
		fmt.Printf("  %s  %-20s %s\n", tagPass(), "Active", s.activeTask)
	} else {
		fmt.Printf("  %s  %-20s %snone  (ztask start <id>)%s\n", tagWarn(), "Active", dim, reset)
	}
	fmt.Printf("  %s  %-20s %d in progress  •  %d to do\n", tagPass(), "Backlog", s.taskWIPCount, s.taskTodoCount)
	fmt.Printf("  %szdash — interactive task picker%s\n", dim, reset)

	if len(s.homeWarnings) > 0 {
		printSection("Home Directory Warnings", cols)
		for _, f := range s.homeWarnings {
			fmt.Printf("  %s  %s%s%s\n", tagWarn(), yellow, f, reset)
			fmt.Printf("         %sloaded by zsh before ZDOTDIR — may shadow zdots config%s\n", dim, reset)
		}
		fmt.Printf("\n  %sRun: cat %s  then migrate or delete%s\n", dim, s.homeWarnings[0], reset)
	}

	if s.modelDisk != "" || s.dockerDisk != "" {
		printSection("Storage", cols)
		if s.modelDisk != "" {
			fmt.Printf("  %s  AI models  %s  (%d GGUF)\n", tagPass(), s.modelDisk, s.modelCount)
		}
		if s.dockerDisk != "" {
			fmt.Printf("  %s  Docker     %s\n", tagPass(), s.dockerDisk)
		}
	}

	fmt.Println("")
	printRule("─", cols)
	if once {
		fmt.Printf("  %szdots-status%s\n", dim, reset)
	} else {
		fmt.Printf("  %srefreshing every %ds  •  q to quit%s\n", dim, interval, reset)
	}
	fmt.Print("\033[J")
}

func tagUp() string   { return fmt.Sprintf("%s%-6s%s", green, "[UP]", reset) }
func tagDown() string { return fmt.Sprintf("%s%-6s%s", red, "[DOWN]", reset) }
func tagWarn() string { return fmt.Sprintf("%s%-6s%s", yellow, "[WARN]", reset) }
func tagPass() string { return fmt.Sprintf("%s%-6s%s", green, "[OK]", reset) }

func field(w int, s string) string {
	if len(s) > w {
		s = s[:w]
	}
	return fmt.Sprintf("%-*s", w, s)
}

func printRule(ch string, width int) {
	fmt.Printf("%s%s%s\n", dim, strings.Repeat(ch, width), reset)
}

func printSection(title string, width int) {
	fmt.Printf("\n%s%s%s%s\n", bold, cyan, title, reset)
	printRule("─", width)
}

func hasTputCols() bool {
	if _, err := exec.LookPath("tput"); err != nil {
		return false
	}
	return exec.Command("tput", "cols").Run() == nil
}

func runTput(capName string) bool {
	return exec.Command("tput", capName).Run() == nil
}

func termCols() int {
	out, err := exec.Command("tput", "cols").Output()
	if err == nil {
		if n, err := strconv.Atoi(strings.TrimSpace(string(out))); err == nil && n > 0 {
			return n
		}
	}
	return 72
}

func shortHostname() string {
	h, err := os.Hostname()
	if err != nil || h == "" {
		return "localhost"
	}
	if i := strings.IndexByte(h, '.'); i > 0 {
		return h[:i]
	}
	return h
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}

func runCmd(timeout time.Duration, name string, args ...string) []byte {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	out, _ := exec.CommandContext(ctx, name, args...).Output()
	return out
}

func parseTraceTime(s string) (time.Time, error) {
	if t, err := time.Parse("2006-01-02T15:04:05-0700", s); err == nil {
		return t, nil
	}
	return time.Parse(time.RFC3339, s)
}

func parseBacklogCounts(raw string) (wip, todo int) {
	section := ""
	for _, line := range strings.Split(raw, "\n") {
		if strings.HasPrefix(line, "In Progress:") {
			section = "wip"
			continue
		}
		if strings.HasPrefix(line, "To Do:") {
			section = "todo"
			continue
		}
		if len(line) > 0 && ((line[0] >= 'A' && line[0] <= 'Z') || (line[0] >= 'a' && line[0] <= 'z')) {
			section = ""
			continue
		}
		if strings.Contains(line, "Z-") {
			switch section {
			case "wip":
				wip++
			case "todo":
				todo++
			}
		}
	}
	return wip, todo
}

func countZdotsKeychainEntries() int {
	if runtime.GOOS != "darwin" {
		return 0
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "/usr/bin/security", "dump-keychain").Output()
	if err != nil {
		return 0
	}
	count := 0
	inZdots := false
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, `0x00000007 <blob>="zdots"`) {
			inZdots = true
			continue
		}
		if strings.Contains(line, `"acct"<blob>=`) {
			if inZdots {
				count++
			}
			inZdots = false
		}
	}
	return count
}

func keychainGet(account string) string {
	if runtime.GOOS != "darwin" {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "/usr/bin/security", "find-generic-password", "-s", "zdots", "-a", account, "-w").Output()
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(out), "\r\n")
}

func readKeys(ch chan<- byte) {
	buf := make([]byte, 1)
	for {
		n, err := os.Stdin.Read(buf)
		if err != nil || n == 0 {
			return
		}
		ch <- buf[0]
	}
}
