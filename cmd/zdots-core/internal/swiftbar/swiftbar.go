// Package swiftbar implements the zdots-swiftbar SwiftBar menu-bar pulse applet.
package swiftbar

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

type processInfo struct {
	pid   int
	etime string
	args  string
}

var (
	whisperProcRe = regexp.MustCompile(`whisper-cli|recipes/yt-transcribe|recipes/transcribe|lib/zdots/jobs/transcribe_chunk`)
	aiProcRe      = regexp.MustCompile(`llama-server.*(--port 11500|--alias (local|ai|default))`)
	embedProcRe   = regexp.MustCompile(`llama-server.*(--port 11501|--alias embed)`)
	workerProcRe  = regexp.MustCompile(`zdots-brain worker`)
	otelProcRe    = regexp.MustCompile(`otelcol-contrib`)
	fileFlagRe    = regexp.MustCompile(`--file\s+([^\s]+)`)
	outBaseRe     = regexp.MustCompile(`--output-base\s+([^\s]+)`)
	usageTopRe    = regexp.MustCompile(`^\s*([0-9]+)\s+(.*)$`)
)

// Run executes the zdots-swiftbar applet and returns an exit code.
func Run(args []string) int {
	return runWithIO(args, os.Stdout, os.Stderr, listProcesses)
}

func runWithIO(args []string, stdout, stderr io.Writer, procLister func() []processInfo) int {
	if len(args) > 0 {
		switch args[0] {
		case "-h", "--help":
			printUsage(stdout)
			return 0
		default:
			fmt.Fprintf(stderr, "zdots-swiftbar: unknown argument: %s\n", args[0])
			return 2
		}
	}

	tracer := otel.New("zdots-swiftbar")
	defer tracer.Flush(250 * time.Millisecond)

	root := tracer.Start("swiftbar.run", nil)

	home, _ := os.UserHomeDir()
	zdotDir := envOr("ZDOTDIR", filepath.Join(home, ".config", "zsh"))
	xdgState := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	stateDir := filepath.Join(xdgState, "zsh")
	zdotsStateDir := filepath.Join(xdgState, "zdots")
	dataDir := envOr("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	modelsDir := envOr("ZDOTS_WHISPER_MODELS_DIR", filepath.Join(dataDir, "whisper-cpp", "models"))
	transcriptsDir := filepath.Join(home, "Downloads", "transcripts")
	_ = os.MkdirAll(transcriptsDir, 0o755)

	platformVersion := "unknown"
	if v, err := os.ReadFile(filepath.Join(zdotDir, "VERSION")); err == nil {
		if s := strings.TrimSpace(string(v)); s != "" {
			platformVersion = s
		}
	}

	doctorState := filepath.Join(stateDir, "zdots-watch.state")
	checkState := filepath.Join(stateDir, "zdots-watch-check.state")
	runsDir := filepath.Join(stateDir, "zdots-watch-runs")
	pipelineEvents := filepath.Join(zdotsStateDir, "pipeline-events.jsonl")

	// ── 1. Platform Health State ───────────────────────────────────────────────
	pass, warn, fail, caps, doctorTS := "0", "0", "0", "?", "never"
	doctorExists := false
	if fields, ok := readKVFile(doctorState); ok {
		doctorExists = true
		pass = fields["pass"]
		warn = fields["warn"]
		fail = fields["fail"]
		caps = fields["caps_errors"]
		doctorTS = fields["ts"]
	}
	checkRC, checkTS := "?", "never"
	if fields, ok := readKVFile(checkState); ok {
		if v := fields["rc"]; v != "" {
			checkRC = v
		}
		if v := fields["ts"]; v != "" {
			checkTS = v
		}
	}

	platGlyph := "🟢"
	if (warn != "" && warn != "0") || caps == "?" || caps == "" {
		platGlyph = "🟡"
	}
	if (fail != "" && fail != "0") || checkRC == "1" {
		platGlyph = "🔴"
	}
	if !doctorExists {
		platGlyph = "⚪"
	}

	// ── 2. Transcription & Subsystems Probe ────────────────────────────────────
	procs := procLister()
	selfPID := os.Getpid()

	txActive := false
	txEtime := ""
	txDetail := "idle"
	aiRunning := false
	embedRunning := false
	workerRunning := false
	otelRunning := false

	for _, p := range procs {
		if !txActive && p.pid != selfPID && whisperProcRe.MatchString(p.args) {
			txActive = true
			txEtime = p.etime
			txDetail = deriveTxDetail(p.args)
		}
		if !aiRunning && aiProcRe.MatchString(p.args) {
			aiRunning = true
		}
		if !embedRunning && embedProcRe.MatchString(p.args) {
			embedRunning = true
		}
		if !workerRunning && workerProcRe.MatchString(p.args) {
			workerRunning = true
		}
		if !otelRunning && otelProcRe.MatchString(p.args) {
			otelRunning = true
		}
	}

	colimaRunning := isSocket(filepath.Join(home, ".colima", "default", "docker.sock")) ||
		isSocket(filepath.Join(home, ".config", "colima", "default", "docker.sock"))

	whisperBin := findWhisperCLI()

	whisperProfile := envOr("ZDOTS_WHISPER_PROFILE", "standard")
	defModel, profDesc := whisperProfileDefaults(whisperProfile)
	whisperModel := envOr("ZDOTS_WHISPER_MODEL_FILE", defModel)

	modelInstalled := false
	modelSize := "?"
	if fi, err := os.Stat(filepath.Join(modelsDir, whisperModel)); err == nil && !fi.IsDir() {
		modelInstalled = true
		modelSize = humanSize(fi.Size())
	}

	lastTxJob, lastTxEvent, lastTxTS, lastTxFailed := readLastPipelineEvent(pipelineEvents)
	ingestCount := countDirs(filepath.Join(zdotsStateDir, "ingest-sources"))

	var txGlyph, txStatusShort, txDesc, txColor string
	switch {
	case txActive:
		txGlyph = "🎙️⚡"
		txStatusShort = "transcribing"
		txDesc = fmt.Sprintf("Transcribing (%s) · %s", txDetail, txEtime)
		txColor = "orange"
	case whisperBin == "":
		txGlyph = "🎙️❌"
		txStatusShort = "missing cli"
		txDesc = "whisper-cli not installed"
		txColor = "red"
	case !modelInstalled:
		txGlyph = "🎙️⚠️"
		txStatusShort = "missing model"
		txDesc = "Model missing: " + whisperModel
		txColor = "orange"
	case lastTxFailed:
		txGlyph = "🎙️⚠️"
		txStatusShort = "last job failed"
		txDesc = fmt.Sprintf("Last job failed: %s (%s)", lastTxJob, lastTxTS)
		txColor = "orange"
	default:
		txGlyph = "🎙️"
		txStatusShort = "ready"
		txDesc = fmt.Sprintf("Ready · %s (%s %s)", whisperProfile, whisperModel, modelSize)
		txColor = "green"
	}

	root.SetAttr("plat_glyph", platGlyph)
	root.SetAttr("tx_status", txStatusShort)
	root.SetAttr("ai_running", aiRunning)
	root.SetAttr("embed_running", embedRunning)
	root.SetAttr("worker_running", workerRunning)
	root.SetAttr("colima_running", colimaRunning)
	root.SetAttr("otel_running", otelRunning)

	// ── 4. Menu Bar Title ──────────────────────────────────────────────────────
	if txActive {
		fmt.Fprintf(stdout, "%s 🎙️⚡ %s\n", platGlyph, txEtime)
	} else if txGlyph != "🎙️" {
		fmt.Fprintf(stdout, "%s %s\n", platGlyph, txGlyph)
	} else {
		fmt.Fprintf(stdout, "%s 🎙️\n", platGlyph)
	}
	fmt.Fprintln(stdout, "---")

	fmt.Fprintf(stdout, "🧭 Astronomicon: %s | color=gray font=bold\n", platformVersion)
	fmt.Fprintf(stdout, "-- Verify six versioned surfaces: zdots-doctor | bash=%s/bin/zdots-doctor terminal=true size=11\n", zdotDir)
	fmt.Fprintln(stdout, "-- SwiftBar uses the zdots epoch; it has no separate release marker | size=11 color=gray")
	fmt.Fprintln(stdout, "---")

	// ── 5. Dropdown: Featured Transcription Section ────────────────────────────
	binDisplay := whisperBin
	if binDisplay == "" {
		binDisplay = "not found"
	}
	fmt.Fprintf(stdout, "🎙️ Transcription: %s | color=%s font=bold\n", txStatusShort, txColor)
	fmt.Fprintf(stdout, "-- State: %s | color=%s\n", txDesc, txColor)
	fmt.Fprintf(stdout, "-- Profile: %s (%s) | size=11 color=gray\n", whisperProfile, profDesc)
	fmt.Fprintf(stdout, "-- Active Model: %s (%s) | size=11\n", whisperModel, modelSize)
	fmt.Fprintf(stdout, "-- Engine Binary: %s | size=11 color=gray\n", binDisplay)
	fmt.Fprintf(stdout, "-- Ingest Sources: %d stored in ~/.local/state/zdots/ingest-sources | size=11 color=gray\n", ingestCount)
	if lastTxJob != "" {
		fmt.Fprintf(stdout, "-- Last Pipeline Event: %s (%s) at %s | size=11 color=gray\n", lastTxJob, lastTxEvent, lastTxTS)
	}
	fmt.Fprintln(stdout, "-- Models on Disk: | size=12")
	for _, m := range listBinModels(modelsDir) {
		if m.name == whisperModel {
			fmt.Fprintf(stdout, "---- ● %s (%s) [active] | color=green\n", m.name, m.size)
		} else {
			fmt.Fprintf(stdout, "---- ○ %s (%s) | color=normal\n", m.name, m.size)
		}
	}
	fmt.Fprintln(stdout, "-- Actions: | size=12")
	fmt.Fprintf(stdout, "---- 🎬 Transcribe YouTube URL (interactive)... | bash=/bin/zsh param0=-ic param1=\"echo '=== YouTube Transcription Pipeline ==='; echo -n 'Enter YouTube URL: '; read url; if [[ -n \\\"\\$url\\\" ]]; then \\\"%s/recipes/yt-transcribe\\\" \\\"\\$url\\\"; else echo 'Cancelled.'; fi; echo 'Press Enter to close'; read\" terminal=true\n", zdotDir)
	fmt.Fprintf(stdout, "---- 🎧 Transcribe Local Audio File (interactive)... | bash=/bin/zsh param0=-ic param1=\"echo '=== Whisper Local Transcription ==='; echo -n 'Enter audio file path: '; read f; if [[ -f \\\"\\$f\\\" ]]; then \\\"%s/bin/whisper-ctl\\\" transcribe \\\"\\$f\\\"; else echo 'File not found.'; fi; echo 'Press Enter to close'; read\" terminal=true\n", zdotDir)
	fmt.Fprintf(stdout, "---- 📦 Manage Models (whisper-ctl)... | bash=/bin/zsh param0=-ic param1=\"\\\"%s/bin/whisper-ctl\\\" model-list; echo ''; \\\"%s/bin/whisper-ctl\\\" --help; exec zsh\" terminal=true\n", zdotDir, zdotDir)
	fmt.Fprintf(stdout, "---- 📂 Open Transcripts Directory | bash=/usr/bin/open param0=\"%s\" terminal=false\n", transcriptsDir)
	fmt.Fprintf(stdout, "---- 🗃️ Open Ingest Sources Directory | bash=/usr/bin/open param0=\"%s/ingest-sources\" terminal=false\n", zdotsStateDir)
	fmt.Fprintf(stdout, "---- 📁 Open Models Directory | bash=/usr/bin/open param0=\"%s\" terminal=false\n", modelsDir)
	fmt.Fprintln(stdout, "---")

	// ── 6. Dropdown: Subsystems Status Matrix ──────────────────────────────────
	fmt.Fprintln(stdout, "Platform Subsystems | size=12 font=bold")
	fmt.Fprintf(stdout, "-- 🎙️ Whisper Transcription: %s | color=%s bash=%s/bin/whisper-ctl param0=config terminal=true\n", txStatusShort, txColor, zdotDir)
	fmt.Fprintf(stdout, "-- 🤖 AI Inference (11500): %s | color=%s bash=%s/bin/llama-ctl param0=status terminal=true\n", stateLabel(aiRunning, "Online", "Standby"), stateColor(aiRunning, "green", "gray"), zdotDir)
	fmt.Fprintf(stdout, "-- 🧠 Embeddings Engine (11501): %s | color=%s bash=%s/bin/llama-ctl param0=status terminal=true\n", stateLabel(embedRunning, "Online", "Standby"), stateColor(embedRunning, "green", "gray"), zdotDir)
	fmt.Fprintf(stdout, "-- ⚙️ Async Pipeline Worker: %s | color=%s bash=%s/bin/zsvc param0=status param1=worker terminal=true\n", stateLabel(workerRunning, "Running", "Stopped"), stateColor(workerRunning, "green", "gray"), zdotDir)
	fmt.Fprintf(stdout, "-- 🐳 Colima Container Engine: %s | color=%s bash=%s/bin/colima-status terminal=true\n", stateLabel(colimaRunning, "Active", "Offline"), stateColor(colimaRunning, "green", "gray"), zdotDir)
	fmt.Fprintf(stdout, "-- 📊 Telemetry Collector (4318): %s | color=%s bash=%s/bin/otel-collector param0=status terminal=true\n", stateLabel(otelRunning, "Active", "Offline"), stateColor(otelRunning, "green", "gray"), zdotDir)
	fmt.Fprintln(stdout, "---")

	// ── 7. Dropdown: Platform Doctor & Health ──────────────────────────────────
	dc, docStatus := "green", "Healthy"
	if warn != "" && warn != "0" {
		dc, docStatus = "orange", "Degraded"
	}
	if fail != "" && fail != "0" {
		dc, docStatus = "red", "Alert"
	}
	fmt.Fprintf(stdout, "🩺 Platform Doctor: %s pass · %s warn · %s fail (%s) | color=%s font=bold\n",
		emptyAsQ(pass), emptyAsQ(warn), emptyAsQ(fail), docStatus, dc)
	fmt.Fprintf(stdout, "-- last run %s | size=11 color=gray\n", doctorTS)
	for _, line := range matchingLines(doctorState, []string{"warn|", "fail|"}, 6) {
		lc := "orange"
		if strings.HasPrefix(line, "fail|") {
			lc = "red"
		}
		fmt.Fprintf(stdout, "-- %s | size=12 color=%s\n", strings.ReplaceAll(line, "|", " "), lc)
	}
	if evDoctor := latestGlob(runsDir, "doctor-*.log"); evDoctor != "" {
		fmt.Fprintf(stdout, "-- 📄 Open Doctor Evidence | bash=/usr/bin/open param0=-t param1=\"%s\" terminal=false\n", evDoctor)
	}

	// ── 8. Dropdown: Nightly Suite & Capabilities ──────────────────────────────
	switch checkRC {
	case "0":
		fmt.Fprintln(stdout, "🧪 Test Suite: green | color=green font=bold")
	case "?":
		fmt.Fprintln(stdout, "🧪 Test Suite: no state yet (next nightly re-seeds) | color=gray font=bold")
	default:
		fails := matchingLines(checkState, []string{"fail|", "suite|"}, 0)
		fmt.Fprintf(stdout, "🧪 Test Suite: rc=%s (%d failing) | color=red font=bold\n", checkRC, len(fails))
		for i, line := range fails {
			if i >= 4 {
				break
			}
			fmt.Fprintf(stdout, "-- %s | size=12 color=red\n", strings.ReplaceAll(line, "|", " "))
		}
	}
	fmt.Fprintf(stdout, "-- last run %s · nightly 03:17 | size=11 color=gray\n", checkTS)
	if evCheck := latestGlob(runsDir, "check-*.log"); evCheck != "" {
		fmt.Fprintf(stdout, "-- 📄 Open Suite Evidence | bash=/usr/bin/open param0=-t param1=\"%s\" terminal=false\n", evCheck)
	}

	capsColor := "orange"
	if caps == "0" {
		capsColor = "green"
	}
	fmt.Fprintf(stdout, "📐 Capabilities: %s contract error(s) | color=%s\n", emptyAsQ(caps), capsColor)
	fmt.Fprintln(stdout, "---")

	// ── 9. Dropdown: Usage & Velocity ──────────────────────────────────────────
	usageBin := filepath.Join(zdotDir, "bin", "zdots-usage")
	if fi, err := os.Stat(usageBin); err == nil && !fi.IsDir() && fi.Mode()&0o111 != 0 {
		if topLine := queryUsageTop(usageBin); topLine != "" {
			fmt.Fprintf(stdout, "📊 Usage — %s | size=12\n", topLine)
		}
		fmt.Fprintf(stdout, "-- full report: zdots-usage | bash=%s param0=summary terminal=true size=11\n", usageBin)
	}
	fmt.Fprintln(stdout, "🌀 Loop velocity: dormant — first domino Z-289 | color=gray size=12")
	fmt.Fprintln(stdout, "---")

	// ── 10. Dropdown: Operator Actions ─────────────────────────────────────────
	fmt.Fprintf(stdout, "🩺 Run Doctor Now | bash=%s/bin/zdots-doctor terminal=true\n", zdotDir)
	fmt.Fprintf(stdout, "🧪 Run Check Suite | bash=%s/bin/check terminal=true\n", zdotDir)
	fmt.Fprintf(stdout, "🚀 Start Platform Services (zdots-ctl up) | bash=%s/bin/zdots-ctl param0=up terminal=true\n", zdotDir)
	fmt.Fprintln(stdout, "🔄 Refresh SwiftBar Pulse | refresh=true")

	root.End(true, "")
	return 0
}

func printUsage(w io.Writer) {
	fmt.Fprint(w, `Usage: zdots-swiftbar [--help]

Platform pulse in SwiftBar dialect (Z-288).
Emits menu-bar standing state and dropdown for SwiftBar, covering platform
health, the shared Astronomicon epoch, subsystem matrix, and transcription telemetry.

Options:
  -h, --help    Show this help message and exit.

Standing Indicators:
  Platform:     🟢 Healthy · 🟡 Degraded · 🔴 Critical · ⚪ Unseeded
  Whisper:      🎙️ Ready · 🎙️⚡ Transcribing · 🎙️⚠️ Warning · 🎙️❌ Missing

Subsystems Monitored:
  🎙️ Whisper    Local audio transcription (whisper.cpp / whisper-ctl)
  🤖 Local AI    Inference server (llama-server / llama-ctl, port 11500)
  🧠 Embeddings  Local embedding server (nomic-embed, port 11501)
  ⚙️ Worker      Async background queue runner (zdots-worker)
  🐳 Colima      Container runtime (Docker socket)
  📊 Observability OpenObserve log/metric engine & OTel Collector
`)
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func readKVFile(path string) (map[string]string, bool) {
	f, err := os.Open(path)
	if err != nil {
		return nil, false
	}
	defer f.Close()
	out := make(map[string]string)
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if k, v, ok := strings.Cut(line, "="); ok {
			if _, exists := out[k]; !exists {
				out[k] = v
			}
		}
	}
	return out, true
}

func listProcesses() []processInfo {
	out, err := exec.Command("ps", "-ax", "-o", "pid=,etime=,args=").Output()
	if err != nil {
		return nil
	}
	var procs []processInfo
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		pid, err := strconv.Atoi(fields[0])
		if err != nil {
			continue
		}
		procs = append(procs, processInfo{
			pid:   pid,
			etime: fields[1],
			args:  strings.Join(fields[2:], " "),
		})
	}
	return procs
}

func deriveTxDetail(cmd string) string {
	switch {
	case strings.Contains(cmd, "whisper-cli"):
		if m := fileFlagRe.FindStringSubmatch(cmd); len(m) == 2 && m[1] != "" {
			return filepath.Base(m[1])
		}
		return "whisper-cli"
	case strings.Contains(cmd, "yt-transcribe"):
		if strings.Contains(cmd, "--from-wav") {
			target := "decode"
			if m := outBaseRe.FindStringSubmatch(cmd); len(m) == 2 && m[1] != "" {
				target = filepath.Base(m[1])
			}
			return "chunk: " + target
		}
		return "yt-transcribe"
	case strings.Contains(cmd, "transcribe_chunk"):
		return "worker chunk"
	default:
		return "audio decode"
	}
}

func findWhisperCLI() string {
	if p, err := exec.LookPath("whisper-cli"); err == nil {
		return p
	}
	const hb = "/opt/homebrew/bin/whisper-cli"
	if fi, err := os.Stat(hb); err == nil && !fi.IsDir() && fi.Mode()&0o111 != 0 {
		return hb
	}
	return ""
}

func whisperProfileDefaults(profile string) (string, string) {
	switch profile {
	case "standard":
		return "ggml-large-v3-turbo.bin", "balanced turbo"
	case "max-accuracy":
		return "ggml-large-v3.bin", "maximum accuracy"
	case "light":
		return "ggml-small.en.bin", "fast English"
	default:
		return "ggml-large-v3-turbo.bin", "custom profile"
	}
}

func isSocket(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.Mode()&os.ModeSocket != 0
}

func humanSize(n int64) string {
	const (
		kb = 1024.0
		mb = kb * 1024
		gb = mb * 1024
	)
	f := float64(n)
	switch {
	case f >= gb:
		return fmt.Sprintf("%.1fG", f/gb)
	case f >= mb:
		return fmt.Sprintf("%.0fM", f/mb)
	case f >= kb:
		return fmt.Sprintf("%.0fK", f/kb)
	default:
		return fmt.Sprintf("%dB", n)
	}
}

func readLastPipelineEvent(path string) (job, event, ts string, failed bool) {
	f, err := os.Open(path)
	if err != nil {
		return "", "", "", false
	}
	defer f.Close()

	var lastLine string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if strings.Contains(line, `"job_type":"transcribe_chunk"`) || strings.Contains(line, `"job_type":"ingest_media"`) {
			lastLine = line
		}
	}
	if lastLine == "" {
		return "", "", "", false
	}
	var ev struct {
		JobType string `json:"job_type"`
		Event   string `json:"event"`
		TS      string `json:"ts"`
	}
	if json.Unmarshal([]byte(lastLine), &ev) != nil {
		return "", "", "", false
	}
	cleanTS := strings.ReplaceAll(strings.SplitN(ev.TS, ".", 2)[0], "T", " ")
	return ev.JobType, ev.Event, cleanTS, ev.Event == "failed"
}

func countDirs(path string) int {
	entries, err := os.ReadDir(path)
	if err != nil {
		return 0
	}
	n := 0
	for _, e := range entries {
		if e.IsDir() {
			n++
		}
	}
	return n
}

type binModel struct {
	name string
	size string
}

func listBinModels(dir string) []binModel {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []binModel
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".bin") {
			continue
		}
		sz := "?"
		if fi, err := e.Info(); err == nil {
			sz = humanSize(fi.Size())
		}
		out = append(out, binModel{name: e.Name(), size: sz})
	}
	return out
}

func matchingLines(path string, prefixes []string, limit int) []string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		for _, p := range prefixes {
			if strings.HasPrefix(line, p) {
				out = append(out, line)
				if limit > 0 && len(out) >= limit {
					return out
				}
				break
			}
		}
	}
	return out
}

func latestGlob(dir, pattern string) string {
	matches, err := filepath.Glob(filepath.Join(dir, pattern))
	if err != nil || len(matches) == 0 {
		return ""
	}
	sort.Sort(sort.Reverse(sort.StringSlice(matches)))
	return matches[0]
}

func queryUsageTop(usageBin string) string {
	out, err := exec.Command(usageBin, "top", "--top", "1").Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		if m := usageTopRe.FindStringSubmatch(line); len(m) == 3 {
			return fmt.Sprintf("top: %s (%sx)", m[2], m[1])
		}
	}
	return ""
}

func stateLabel(ok bool, up, down string) string {
	if ok {
		return up
	}
	return down
}

func stateColor(ok bool, up, down string) string {
	if ok {
		return up
	}
	return down
}

func emptyAsQ(s string) string {
	if s == "" {
		return "?"
	}
	return s
}
