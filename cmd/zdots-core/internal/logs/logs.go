package logs

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

const (
	warnBytes int64 = 100 * 1024 * 1024
	critBytes int64 = 500 * 1024 * 1024
)

func usage() string {
	return `bin/zdots-logs — Centralized log operations for all zdots-managed services.

Every log source registered in svc-registry.bash is available by its service
name. Use "all" (or no service argument) to operate across all sources.

Commands:
  list   [--json]              Table of all log sources: path, size, status
  check  [--json]              Size health check; warns ≥100M, fails ≥500M
  tail   [<svc>] [-n N]       Follow logs (default: all, -n 50)
  show   [<svc>] [-n N]       Last N lines, no follow (default: all, -n 100)
  head   [<svc>] [-n N]       First N lines (default: all, -n 50)
  grep   <pattern> [<svc>]    Search across log files

Service names match zsvc identifiers: llama embed otel o2 colima nginx
  postgres redis worker — or any registered alias.
Use "all" or omit the service to target every registered log source.

Options:
  -n, --lines N    Number of lines (default varies by command)
  --json           Machine-readable output (list, check commands)
  -h, --help       Show this help
`
}

type logSource struct {
	Name    string
	Display string
	Path    string
	Aliases []string
}

func registry() []logSource {
	home, _ := os.UserHomeDir()
	xdgState := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	state := filepath.Join(xdgState, "zsh")
	brew := envOr("HOMEBREW_PREFIX", "/opt/homebrew")
	pgVer := envOr("ZDOTS_POSTGRES_VERSION", "18")

	return []logSource{
		{Name: "llama", Display: "llama-server", Path: filepath.Join(state, "llama-server.log"), Aliases: []string{"llama-server", "ai", "server"}},
		{Name: "embed", Display: "llama-embed", Path: filepath.Join(state, "llama-embed.log"), Aliases: []string{"llama-embed", "embedding"}},
		{Name: "otel", Display: "otel-collector", Path: filepath.Join(state, "otel-collector.log"), Aliases: []string{"otel-collector", "telemetry", "collector"}},
		{Name: "jaeger", Display: "jaeger", Path: filepath.Join(state, "jaeger.log"), Aliases: []string{"tracing", "trace-ui"}},
		{Name: "o2", Display: "openobserve", Path: filepath.Join(state, "openobserve.log"), Aliases: []string{"openobserve", "observability", "obs", "telemetry-ui"}},
		{Name: "nginx", Display: "nginx", Path: filepath.Join(brew, "var", "log", "nginx", "error.log"), Aliases: []string{"web", "proxy"}},
		{Name: "postgres", Display: "postgresql@" + pgVer, Path: filepath.Join(brew, "var", "log", "postgresql@"+pgVer+".log"), Aliases: []string{"postgresql", "pg", "db", "database"}},
		{Name: "redis", Display: "redis", Path: filepath.Join(brew, "var", "log", "redis.log"), Aliases: []string{"cache", "kv"}},
		{Name: "worker", Display: "zdots-worker", Path: filepath.Join(state, "zdots-worker.log"), Aliases: []string{"jobs", "brain-worker"}},
		{Name: "status", Display: "zdots-statusd", Path: filepath.Join(state, "zdots-statusd.log"), Aliases: []string{"statusd", "statusd-ctl", "control-plane", "dashboard"}},
		{Name: "gemstash", Display: "gemstash", Path: filepath.Join(state, "gemstash.log"), Aliases: []string{"gems", "gem-cache", "rubygems", "gem-proxy"}},
	}
}

func resolveTarget(target string) ([]logSource, error) {
	srcs := registry()
	if target == "" || target == "all" {
		return srcs, nil
	}
	for _, s := range srcs {
		if s.Name == target {
			return []logSource{s}, nil
		}
		for _, a := range s.Aliases {
			if a == target {
				return []logSource{s}, nil
			}
		}
	}
	return nil, fmt.Errorf("unknown service: %s", target)
}

// Run executes the zdots-logs command and returns the process exit code.
func Run(args []string) int {
	if len(args) == 0 {
		fmt.Print(usage())
		return 0
	}

	cmd := args[0]
	rest := args[1:]

	if cmd == "-h" || cmd == "--help" || cmd == "help" {
		fmt.Print(usage())
		return 0
	}

	tr := otel.New("zdots-logs")
	sp := tr.Start("logs."+cmd, nil)

	var rc int
	switch cmd {
	case "list":
		rc = cmdList(rest)
	case "check":
		rc = cmdCheck(rest)
	case "tail":
		rc = cmdTail(rest)
	case "show":
		rc = cmdShow(rest)
	case "head":
		rc = cmdHead(rest)
	case "grep":
		rc = cmdGrep(rest)
	default:
		fmt.Fprintf(os.Stderr, "zdots-logs: unknown command: %s  (try --help)\n", cmd)
		rc = 1
	}

	sp.SetAttr("exit_code", rc)
	sp.End(rc == 0, "")
	tr.Flush(250 * time.Millisecond)
	return rc
}

func cmdList(args []string) int {
	jsonMode := false
	for _, a := range args {
		if a == "--json" {
			jsonMode = true
		} else if a == "-h" || a == "--help" {
			fmt.Print(usage())
			return 0
		}
	}

	srcs := registry()
	type sourceJSON struct {
		Name     string `json:"name"`
		Path     string `json:"path"`
		Exists   bool   `json:"exists"`
		Bytes    int64  `json:"bytes"`
		Modified string `json:"modified"`
		Status   string `json:"status"`
	}

	if jsonMode {
		out := struct {
			Sources []sourceJSON `json:"sources"`
		}{Sources: make([]sourceJSON, 0, len(srcs))}
		for _, s := range srcs {
			item := sourceJSON{Name: s.Display, Path: s.Path, Modified: "-", Status: "missing"}
			if info, err := os.Stat(s.Path); err == nil && !info.IsDir() {
				item.Exists = true
				item.Bytes = info.Size()
				item.Modified = info.ModTime().Format("2006-01-02T15:04:05")
				item.Status = sizeStatus(info.Size())
			}
			out.Sources = append(out.Sources, item)
		}
		b, _ := json.Marshal(out)
		fmt.Println(string(b))
		return 0
	}

	fmt.Printf("%-16s  %-8s  %-6s  %-16s  %s\n", "NAME", "SIZE", "STATUS", "MODIFIED", "PATH")
	fmt.Println(strings.Repeat("-", 90))
	for _, s := range srcs {
		if info, err := os.Stat(s.Path); err == nil && !info.IsDir() {
			fmt.Printf("%-16s  %-8s  %-6s  %-16s  %s\n",
				s.Display, fmtBytes(info.Size()), sizeStatus(info.Size()), info.ModTime().Format("2006-01-02 15:04"), s.Path)
		} else {
			fmt.Printf("%-16s  %-8s  %-6s  %-16s  %s [missing]\n",
				s.Display, "-", "-", "-", s.Path)
		}
	}
	return 0
}

// CheckText runs the size check and returns the formatted report and exit code.
func CheckText() (string, int) {
	var buf bytes.Buffer
	srcs := registry()
	anyWarn, anyCrit := false, false

	fmt.Fprintf(&buf, "Log size check  (warn ≥%s, crit ≥%s)\n", fmtBytes(warnBytes), fmtBytes(critBytes))
	for _, s := range srcs {
		info, err := os.Stat(s.Path)
		if err != nil || info.IsDir() {
			fmt.Fprintf(&buf, "  %-16s  -         missing\n", s.Display)
			continue
		}
		sz := info.Size()
		st := sizeStatus(sz)
		if st == "warn" {
			anyWarn = true
		} else if st == "crit" {
			anyCrit = true
		}
		label := ""
		if st == "crit" {
			label = "  *** CRITICAL — at risk"
		} else if st == "warn" {
			label = "  ** WARNING — at risk"
		}
		fmt.Fprintf(&buf, "  %-16s  %-8s  %s%s\n", s.Display, fmtBytes(sz), st, label)
		if _, rate, p30, p90 := growthEstimate(info, sz); rate > 0 {
			fmt.Fprintf(&buf, "  %-16s  growth ~%s/day  →  30d: %s  90d: %s  (est.)\n",
				"", fmtBytes(rate), fmtBytes(p30), fmtBytes(p90))
		}
	}
	buf.WriteByte('\n')
	if anyCrit {
		fmt.Fprintf(&buf, "[FAIL] one or more log files exceed %s — rotation needed\n", fmtBytes(critBytes))
		return buf.String(), 1
	}
	if anyWarn {
		fmt.Fprintf(&buf, "[warn] one or more log files exceed %s — monitor closely\n", fmtBytes(warnBytes))
		return buf.String(), 0
	}
	fmt.Fprintf(&buf, "[ok]   all log files within size thresholds\n")
	return buf.String(), 0
}

func cmdCheck(args []string) int {
	jsonMode := false
	for _, a := range args {
		if a == "--json" {
			jsonMode = true
		} else if a == "-h" || a == "--help" {
			fmt.Print(usage())
			return 0
		}
	}

	if !jsonMode {
		text, rc := CheckText()
		fmt.Print(text)
		return rc
	}

	type fileCheck struct {
		Name         string `json:"name"`
		Path         string `json:"path"`
		Exists       bool   `json:"exists"`
		Bytes        *int64 `json:"bytes,omitempty"`
		AgeDays      *int64 `json:"age_days,omitempty"`
		BytesPerDay  *int64 `json:"bytes_per_day,omitempty"`
		Projected30d *int64 `json:"projected_30d,omitempty"`
		Projected90d *int64 `json:"projected_90d,omitempty"`
		Status       string `json:"status"`
	}

	srcs := registry()
	anyWarn, anyCrit := false, false
	files := make([]fileCheck, 0, len(srcs))
	for _, s := range srcs {
		info, err := os.Stat(s.Path)
		if err != nil || info.IsDir() {
			files = append(files, fileCheck{Name: s.Display, Path: s.Path, Exists: false, Status: "missing"})
			continue
		}
		sz := info.Size()
		st := sizeStatus(sz)
		if st == "warn" {
			anyWarn = true
		} else if st == "crit" {
			anyCrit = true
		}
		age, rate, p30, p90 := growthEstimate(info, sz)
		files = append(files, fileCheck{
			Name:         s.Display,
			Path:         s.Path,
			Exists:       true,
			Bytes:        &sz,
			AgeDays:      &age,
			BytesPerDay:  &rate,
			Projected30d: &p30,
			Projected90d: &p90,
			Status:       st,
		})
	}

	payload := struct {
		WarnThresholdBytes int64       `json:"warn_threshold_bytes"`
		CritThresholdBytes int64       `json:"crit_threshold_bytes"`
		Files              []fileCheck `json:"files"`
		AnyWarn            bool        `json:"any_warn"`
		AnyCrit            bool        `json:"any_crit"`
	}{
		WarnThresholdBytes: warnBytes,
		CritThresholdBytes: critBytes,
		Files:              files,
		AnyWarn:            anyWarn,
		AnyCrit:            anyCrit,
	}
	b, _ := json.Marshal(payload)
	fmt.Println(string(b))
	if anyCrit {
		return 1
	}
	return 0
}

func parseTargetAndLines(args []string, defaultLines int) (string, int, error) {
	target := "all"
	lines := defaultLines
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "-n" || a == "--lines":
			if i+1 >= len(args) {
				return "", 0, fmt.Errorf("--lines requires N")
			}
			i++
			n, err := strconv.Atoi(args[i])
			if err != nil || n < 0 {
				return "", 0, fmt.Errorf("invalid lines: %s", args[i])
			}
			lines = n
		case strings.HasPrefix(a, "--lines="):
			val := strings.TrimPrefix(a, "--lines=")
			n, err := strconv.Atoi(val)
			if err != nil || n < 0 {
				return "", 0, fmt.Errorf("invalid lines: %s", val)
			}
			lines = n
		default:
			target = a
		}
	}
	return target, lines, nil
}

func cmdTail(args []string) int {
	target, lines, err := parseTargetAndLines(args, 50)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	srcs, err := resolveTarget(target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	paths := make([]string, 0, len(srcs))
	for _, s := range srcs {
		_ = os.MkdirAll(filepath.Dir(s.Path), 0o755)
		paths = append(paths, s.Path)
	}
	if len(paths) == 1 {
		fmt.Fprintf(os.Stderr, "==> tailing %s — Ctrl+C to stop\n", paths[0])
	} else {
		fmt.Fprintf(os.Stderr, "==> tailing %d log sources — Ctrl+C to stop\n", len(paths))
	}
	cmdArgs := append([]string{"-n", strconv.Itoa(lines), "-F"}, paths...)
	cmd := exec.Command("tail", cmdArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
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

func cmdShow(args []string) int {
	target, lines, err := parseTargetAndLines(args, 100)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	srcs, err := resolveTarget(target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	for _, s := range srcs {
		if info, err := os.Stat(s.Path); err == nil && !info.IsDir() {
			fmt.Printf("\n==> %s <==\n", s.Path)
			for _, ln := range readTailLines(s.Path, lines) {
				fmt.Println(ln)
			}
		} else {
			fmt.Fprintf(os.Stderr, "\n==> %s [not found] <==\n", s.Path)
		}
	}
	return 0
}

func cmdHead(args []string) int {
	target, lines, err := parseTargetAndLines(args, 50)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	srcs, err := resolveTarget(target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	for _, s := range srcs {
		if info, err := os.Stat(s.Path); err == nil && !info.IsDir() {
			fmt.Printf("\n==> %s <==\n", s.Path)
			for _, ln := range readHeadLines(s.Path, lines) {
				fmt.Println(ln)
			}
		} else {
			fmt.Fprintf(os.Stderr, "\n==> %s [not found] <==\n", s.Path)
		}
	}
	return 0
}

func cmdGrep(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "zdots-logs: grep requires a pattern")
		return 1
	}
	pattern := args[0]
	target := "all"
	if len(args) > 1 {
		target = args[1]
	}
	srcs, err := resolveTarget(target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-logs: %v\n", err)
		return 1
	}
	lowerPat := strings.ToLower(pattern)
	foundFile := false
	for _, s := range srcs {
		f, err := os.Open(s.Path)
		if err != nil {
			continue
		}
		foundFile = true
		sc := bufio.NewScanner(f)
		sc.Buffer(make([]byte, 64*1024), 4*1024*1024)
		for sc.Scan() {
			ln := sc.Text()
			if strings.Contains(strings.ToLower(ln), lowerPat) {
				fmt.Printf("%s:%s\n", s.Path, ln)
			}
		}
		_ = f.Close()
	}
	if !foundFile {
		fmt.Fprintln(os.Stderr, "zdots-logs: no log files exist to search")
		return 1
	}
	return 0
}

func readHeadLines(path string, n int) []string {
	if n <= 0 {
		return nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer func() { _ = f.Close() }()
	var out []string
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 64*1024), 4*1024*1024)
	for len(out) < n && sc.Scan() {
		out = append(out, sc.Text())
	}
	return out
}

func readTailLines(path string, n int) []string {
	if n <= 0 {
		return nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer func() { _ = f.Close() }()
	ring := make([]string, n)
	count := 0
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 64*1024), 4*1024*1024)
	for sc.Scan() {
		ring[count%n] = sc.Text()
		count++
	}
	if count <= n {
		return ring[:count]
	}
	start := count % n
	out := make([]string, 0, n)
	out = append(out, ring[start:]...)
	out = append(out, ring[:start]...)
	return out
}

func sizeStatus(sz int64) string {
	if sz >= critBytes {
		return "crit"
	}
	if sz >= warnBytes {
		return "warn"
	}
	return "ok"
}

func fmtBytes(b int64) string {
	switch {
	case b >= 1073741824:
		return fmt.Sprintf("%dG", b/1073741824)
	case b >= 1048576:
		return fmt.Sprintf("%dM", b/1048576)
	case b >= 1024:
		return fmt.Sprintf("%dK", b/1024)
	default:
		return fmt.Sprintf("%dB", b)
	}
}

func growthEstimate(info os.FileInfo, sz int64) (ageDays, rate, proj30, proj90 int64) {
	st, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return 0, 0, 0, 0
	}
	btime := st.Birthtimespec.Sec
	now := time.Now().Unix()
	if btime > 0 && now > btime {
		ageDays = (now - btime) / 86400
		if ageDays < 1 {
			ageDays = 1
		}
		rate = sz / ageDays
		proj30 = sz + rate*30
		proj90 = sz + rate*90
	}
	return ageDays, rate, proj30, proj90
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}
