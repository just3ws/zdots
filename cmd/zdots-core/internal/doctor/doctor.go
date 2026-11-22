package doctor

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
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/config"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/ctl"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/logs"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/zsvc"
)

const (
	clrOK   = "\033[0;32m"
	clrWarn = "\033[0;33m"
	clrErr  = "\033[0;31m"
	clrRst  = "\033[0m"
)

func usage() string {
	return `bin/zdots-doctor — System health check ("brew doctor" for zdots)

Runs environment, repo, XDG compliance, AI tool, and runtime checks,
then delegates the deep runtime probe to ` + "`zdots-ctl check`" + `. Checks adots
as a peer dependency. Exits 0 when no failures are found; exits 1 on any [FAIL].

Usage: zdots-doctor [--no-runtime] [-q|--quiet] [--json]
  --no-runtime   Skip the zdots-ctl check section (fast mode)
  -q, --quiet    Only print warnings and failures
  --json         Output results as JSON (exit code reflects zdots-only status)
`
}

type lineKind int

const (
	kindPass lineKind = iota
	kindOK
	kindSkip
	kindWarn
	kindFail
	kindFix
	kindRaw
	kindAccept
)

type lineItem struct {
	kind lineKind
	text string
}

type sectionResult struct {
	title     string
	lines     []lineItem
	pass      int
	warn      int
	fail      int
	accepted  int
	adotsRC   int
	runtimeRC int
}

func (s *sectionResult) ok(msg string)   { s.lines = append(s.lines, lineItem{kindOK, msg}) }
func (s *sectionResult) skip(msg string) { s.lines = append(s.lines, lineItem{kindSkip, msg}) }
func (s *sectionResult) passLine(msg string) {
	s.pass++
	s.lines = append(s.lines, lineItem{kindPass, msg})
}
func (s *sectionResult) warnLine(msg string) {
	s.warn++
	s.lines = append(s.lines, lineItem{kindWarn, msg})
}
func (s *sectionResult) failLine(msg string) {
	s.fail++
	s.lines = append(s.lines, lineItem{kindFail, msg})
}
func (s *sectionResult) fix(msg string) { s.lines = append(s.lines, lineItem{kindFix, msg}) }
func (s *sectionResult) raw(msg string) {
	if msg != "" {
		s.lines = append(s.lines, lineItem{kindRaw, msg})
	}
}

type envConfig struct {
	home        string
	zdotdir     string
	binDir      string
	stateDir    string
	xdgState    string
	skipRuntime bool
	quiet       bool
	jsonMode    bool
}

type jsonReport struct {
	Status string `json:"status"`
	Checks struct {
		Passed   int `json:"passed"`
		Warnings int `json:"warnings"`
		Failures int `json:"failures"`
	} `json:"checks"`
	PeerAdots struct {
		RC      int  `json:"rc"`
		Healthy bool `json:"healthy"`
	} `json:"peer_adots"`
}

// Run executes the zdots-doctor command and returns the process exit code.
func Run(args []string) int {
	var skipRuntime, quiet, jsonMode bool
	for _, arg := range args {
		switch arg {
		case "--no-runtime":
			skipRuntime = true
		case "-q", "--quiet":
			quiet = true
		case "--json":
			jsonMode = true
		case "-h", "--help":
			fmt.Print(usage())
			return 0
		default:
			fmt.Fprintf(os.Stderr, "zdots-doctor: unknown option: %s\n", arg)
			return 1
		}
	}

	home, _ := os.UserHomeDir()
	zdotdir := envOr("ZDOTDIR", filepath.Join(home, ".config", "zsh"))
	xdgState := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	cfg := envConfig{
		home:        home,
		zdotdir:     zdotdir,
		binDir:      filepath.Join(zdotdir, "bin"),
		stateDir:    filepath.Join(xdgState, "zsh"),
		xdgState:    xdgState,
		skipRuntime: skipRuntime,
		quiet:       quiet,
		jsonMode:    jsonMode,
	}

	tr := otel.New("zdots-doctor")
	rootSpan := tr.Start("doctor.run", nil)
	rootSpan.SetAttr("no_runtime", skipRuntime)
	rootSpan.SetAttr("quiet", quiet)
	rootSpan.SetAttr("json_mode", jsonMode)

	appendTraceLog(cfg.xdgState, "doctor_check", "start")

	type task struct {
		name string
		fn   func() *sectionResult
	}
	tasks := []task{
		{"doctor.env", func() *sectionResult { return checkEnv(cfg) }},
		{"doctor.beacon", func() *sectionResult { return checkBeacon(cfg) }},
		{"doctor.repo", func() *sectionResult { return checkRepo(cfg) }},
		{"doctor.xdg", func() *sectionResult { return checkXDG(cfg) }},
		{"doctor.ai_tools", func() *sectionResult { return checkAITools(cfg) }},
		{"doctor.gh", func() *sectionResult { return checkGH(cfg) }},
	}
	if envOr("ZDOTS_CONTEXT", "home") == "work" {
		tasks = append(tasks, task{"doctor.work", func() *sectionResult { return checkWork(cfg) }})
	}
	tasks = append(tasks,
		task{"doctor.services", func() *sectionResult { return checkServices(cfg) }},
		task{"doctor.inference", func() *sectionResult { return checkInference(cfg) }},
		task{"doctor.observability", func() *sectionResult { return checkObservability(cfg) }},
		task{"doctor.logs", func() *sectionResult { return checkLogs(cfg) }},
		task{"doctor.runtime", func() *sectionResult { return checkRuntime(cfg) }},
		task{"doctor.peer", func() *sectionResult { return checkPeer(cfg) }},
		task{"doctor.work_boundary", func() *sectionResult { return &sectionResult{title: "Work-data boundary"} }},
		task{"doctor.git_hooks", func() *sectionResult { return checkGitHooks(cfg) }},
		task{"doctor.local_contracts", func() *sectionResult { return checkLocalContracts(cfg) }},
	)

	results := make([]*sectionResult, len(tasks))
	var wg sync.WaitGroup
	for i, t := range tasks {
		wg.Add(1)
		go func(idx int, tk task) {
			defer wg.Done()
			sp := tr.Start(tk.name, rootSpan)
			res := tk.fn()
			results[idx] = res
			if res != nil {
				sp.SetAttr("pass", res.pass)
				sp.SetAttr("warn", res.warn)
				sp.SetAttr("fail", res.fail)
				sp.End(res.fail == 0 && res.runtimeRC == 0, "")
			} else {
				sp.End(true, "")
			}
		}(i, t)
	}
	wg.Wait()

	totalAccepted := applyAccepts(results, loadAccepts(acceptFile(cfg)), cfg.home)

	var totalPass, totalWarn, totalFail, adotsRC, runtimeRC int
	for _, r := range results {
		if r == nil {
			continue
		}
		totalPass += r.pass
		totalWarn += r.warn
		totalFail += r.fail
		if r.adotsRC != 0 {
			adotsRC = r.adotsRC
		}
		if r.runtimeRC != 0 {
			runtimeRC = r.runtimeRC
		}
	}

	statusStr := "pass"
	if totalFail > 0 || runtimeRC != 0 {
		statusStr = "fail"
	} else if totalWarn > 0 {
		statusStr = "warn"
	}

	rootSpan.SetAttr("passed", totalPass)
	rootSpan.SetAttr("warnings", totalWarn)
	rootSpan.SetAttr("failures", totalFail)
	rootSpan.SetAttr("runtime_rc", runtimeRC)
	rootSpan.SetAttr("status", statusStr)
	rootSpan.End(totalFail == 0 && runtimeRC == 0, "")
	tr.Flush(250 * time.Millisecond)

	totalChecks := totalPass + totalWarn + totalFail + totalAccepted
	acceptedNote := ""
	if totalAccepted > 0 {
		acceptedNote = fmt.Sprintf(" (%d accepted)", totalAccepted)
	}
	appendTraceLog(cfg.xdgState, "doctor_check", fmt.Sprintf("complete status=%s checks=%d", statusStr, totalChecks))

	if jsonMode {
		var rep jsonReport
		if totalFail == 0 {
			rep.Status = "pass"
		} else {
			rep.Status = "fail"
		}
		rep.Checks.Passed = totalPass
		rep.Checks.Warnings = totalWarn
		rep.Checks.Failures = totalFail
		rep.PeerAdots.RC = adotsRC
		rep.PeerAdots.Healthy = adotsRC == 0
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(rep)
		if totalFail > 0 {
			return totalFail
		}
		return 0
	}

	for _, r := range results {
		if r != nil {
			printSection(r, quiet)
		}
	}

	fmt.Println()
	fmt.Println(strings.Repeat("━", 59))
	if totalFail == 0 && totalWarn == 0 && runtimeRC == 0 {
		fmt.Printf("zdots doctor: all %d checks passed%s\n", totalChecks, acceptedNote)
	} else if totalFail == 0 && runtimeRC == 0 {
		fmt.Printf("zdots doctor: %d passed · %d warning(s) · 0 failures%s\n", totalPass, totalWarn, acceptedNote)
	} else {
		fmt.Printf("zdots doctor: %d passed · %d warning(s) · %d failure(s)%s\n", totalPass, totalWarn, totalFail, acceptedNote)
	}

	if totalFail == 0 && runtimeRC == 0 {
		return 0
	}
	return 1
}

func printSection(r *sectionResult, quiet bool) {
	fmt.Println()
	pad := 55 - len(r.title)
	if pad < 0 {
		pad = 0
	}
	fmt.Printf("━━━ %s %s\n", r.title, strings.Repeat("━", pad))
	for _, l := range r.lines {
		switch l.kind {
		case kindPass:
			if !quiet {
				fmt.Printf("  %s[ok]   %s%s\n", clrOK, clrRst, l.text)
			}
		case kindOK:
			if !quiet {
				fmt.Printf("  [ok]   %s\n", l.text)
			}
		case kindSkip:
			if !quiet {
				fmt.Printf("  [----] %s\n", l.text)
			}
		case kindWarn:
			fmt.Printf("  %s[warn] %s%s\n", clrWarn, clrRst, l.text)
		case kindFail:
			fmt.Printf("  %s[FAIL] %s%s\n", clrErr, clrRst, l.text)
		case kindAccept:
			if !quiet {
				fmt.Printf("  [accept] %s\n", l.text)
			}
		case kindFix:
			fmt.Printf("         fix: %s\n", l.text)
		case kindRaw:
			fmt.Println(strings.TrimRight(l.text, "\n"))
		}
	}
}

func checkEnv(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Environment"}
	if info, err := os.Stat(cfg.zdotdir); err == nil && info.IsDir() && os.Getenv("ZDOTDIR") != "" {
		s.passLine("ZDOTDIR  " + os.Getenv("ZDOTDIR"))
	} else if info, err := os.Stat(cfg.zdotdir); err == nil && info.IsDir() && os.Getenv("ZDOTDIR") == "" {
		s.failLine("ZDOTDIR  not set or missing: <unset>")
		s.fix("export ZDOTDIR=$HOME/.config/zsh")
	} else {
		val := os.Getenv("ZDOTDIR")
		if val == "" {
			val = "<unset>"
		}
		s.failLine("ZDOTDIR  not set or missing: " + val)
		s.fix("export ZDOTDIR=$HOME/.config/zsh")
	}

	if ctx := os.Getenv("ZDOTS_CONTEXT"); ctx != "" {
		s.passLine("ZDOTS_CONTEXT  " + ctx)
	} else {
		s.warnLine("ZDOTS_CONTEXT  not set (defaulting to 'home')")
		s.fix("Add: export ZDOTS_CONTEXT=home  (or work) to env.sh")
	}

	aiMode := envOr("ZDOTS_AI_MODE", "local")
	switch aiMode {
	case "local", "none":
		s.passLine("ZDOTS_AI_MODE  " + aiMode)
	case "cloud":
		s.warnLine("ZDOTS_AI_MODE  cloud — data leaves the machine")
	default:
		s.warnLine("ZDOTS_AI_MODE  " + aiMode + " (unrecognised)")
	}

	for _, v := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"} {
		if val := os.Getenv(v); val != "" {
			s.passLine(v + "  " + val)
		} else {
			s.warnLine(v + "  not set (tools may use non-XDG defaults)")
		}
	}

	if hb := os.Getenv("HOMEBREW_PREFIX"); hb != "" {
		s.passLine("HOMEBREW_PREFIX  " + hb)
	} else {
		s.failLine("HOMEBREW_PREFIX  not set")
		s.fix(`eval "$(brew shellenv)"`)
	}
	return s
}

func checkBeacon(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Platform version (Astronomicon)"}
	verFile := filepath.Join(cfg.zdotdir, "VERSION")
	raw, err := os.ReadFile(verFile)
	if err != nil {
		s.warnLine("zdots  no VERSION beacon at " + verFile)
		s.fix("imperial-date > " + verFile)
		return s
	}
	beacon := strings.TrimSpace(string(raw))
	s.passLine("zdots  " + beacon + "  (the beacon)")

	xdgCfg := envOr("XDG_CONFIG_HOME", filepath.Join(cfg.home, ".config"))
	targets := loadBeaconTargets(cfg, xdgCfg)
	for _, t := range targets {
		if t.label == "zdots" {
			continue
		}
		if t.bare != "" {
			adotsVer, _ := runCmdOut(3*time.Second, "git", "--git-dir="+t.bare, "--work-tree="+cfg.home, "show", "HEAD:VERSION")
			adotsVer = strings.TrimSpace(adotsVer)
			if adotsVer != "" {
				if adotsVer == beacon {
					s.passLine(fmt.Sprintf("%s  %s  (in sync)", t.label, adotsVer))
				} else {
					s.warnLine(fmt.Sprintf("%s  %s ≠ beacon %s — deploy drift", t.label, adotsVer, beacon))
				}
			} else {
				s.warnLine(fmt.Sprintf("%s  no committed VERSION — rollout pending", t.label))
			}
			continue
		}
		if b, err := os.ReadFile(t.path); err == nil {
			v := strings.TrimSpace(string(b))
			if v == beacon {
				s.passLine(fmt.Sprintf("%s  %s  (in sync)", t.label, v))
			} else {
				s.warnLine(fmt.Sprintf("%s  %s ≠ beacon %s — deploy drift", t.label, v, beacon))
			}
		} else {
			s.warnLine(fmt.Sprintf("%s  no VERSION at %s — rollout pending", t.label, t.path))
		}
	}
	return s
}

func checkRepo(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Repo"}
	if out, rc := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "rev-parse", "--is-inside-work-tree"); rc == 0 && strings.TrimSpace(out) == "true" {
		commit, _ := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "rev-parse", "--short", "HEAD")
		commit = strings.TrimSpace(commit)
		if commit == "" {
			commit = "unknown"
		}
		s.passLine(fmt.Sprintf("commit  %s  (%s)", commit, cfg.zdotdir))

		_, rc1 := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "diff", "--quiet")
		_, rc2 := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "diff", "--cached", "--quiet")
		if rc1 == 0 && rc2 == 0 {
			s.passLine("working tree  clean")
		} else {
			s.warnLine("working tree  has uncommitted changes")
			s.fix("git diff  (review changes)")
		}

		upstream, urc := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "rev-parse", "--abbrev-ref", "@{upstream}")
		if urc == 0 && strings.TrimSpace(upstream) != "" {
			ahead, _ := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "rev-list", "--count", "@{upstream}..HEAD")
			behind, _ := runCmdOut(3*time.Second, "git", "-C", cfg.zdotdir, "rev-list", "--count", "HEAD..@{upstream}")
			aStr := strings.TrimSpace(ahead)
			bStr := strings.TrimSpace(behind)
			if aStr == "" {
				aStr = "?"
			}
			if bStr == "" {
				bStr = "?"
			}
			if aStr == "0" && bStr == "0" {
				s.passLine("origin  up to date")
			} else if bStr != "0" {
				s.warnLine(fmt.Sprintf("origin  %s commit(s) behind — run: git pull", bStr))
				s.fix("git pull")
			} else {
				s.passLine(fmt.Sprintf("origin  %s commit(s) ahead (unpushed)", aStr))
			}
		} else {
			s.skip("origin  no upstream configured")
		}
	} else {
		s.warnLine(fmt.Sprintf("repo  %s is not a git repository", cfg.zdotdir))
	}

	// Latest update-local summary
	matches, _ := filepath.Glob(filepath.Join(cfg.stateDir, "zdots-update-local-*.summary.md"))
	if len(matches) > 0 {
		sort.Slice(matches, func(i, j int) bool {
			ii, _ := os.Stat(matches[i])
			ij, _ := os.Stat(matches[j])
			if ii == nil || ij == nil {
				return matches[i] > matches[j]
			}
			return ii.ModTime().After(ij.ModTime())
		})
		latest := matches[0]
		ulResult := "unknown"
		if data, err := os.ReadFile(latest); err == nil {
			for _, line := range strings.Split(string(data), "\n") {
				if strings.HasPrefix(line, "**result:") || strings.HasPrefix(line, "- result:") {
					val := strings.TrimPrefix(line, "**")
					val = strings.TrimSuffix(val, "**")
					val = strings.TrimPrefix(val, "- ")
					val = strings.TrimPrefix(val, "result: ")
					ulResult = strings.TrimSpace(val)
					break
				}
			}
		}
		tsRe := regexp.MustCompile(`[0-9]{8}T[0-9]{6}`)
		ulTS := tsRe.FindString(filepath.Base(latest))
		if ulTS == "" {
			ulTS = "unknown"
		}
		if strings.Contains(ulResult, "complete") {
			s.passLine(fmt.Sprintf("last update-local  complete  (%s)", ulTS))
		} else {
			s.warnLine(fmt.Sprintf("last update-local  %s  (%s)", ulResult, ulTS))
			s.fix("zdots-update-local")
		}
	} else {
		s.warnLine("last update-local  no run found")
		s.fix("zdots-update-local")
	}
	return s
}

func checkXDG(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "XDG compliance"}
	for _, f := range []string{".zshrc", ".zprofile", ".zlogin", ".zlogout"} {
		p := filepath.Join(cfg.home, f)
		if info, err := os.Stat(p); err == nil && !info.IsDir() {
			s.warnLine(fmt.Sprintf("%s  present — loaded before ZDOTDIR, may shadow zdots config", p))
			s.fix(fmt.Sprintf("mv %s %s/conf.d/  (or delete if empty)", p, cfg.zdotdir))
		}
	}

	if _, err := exec.LookPath("colima-status"); err == nil {
		if _, rc := runCmdOut(3*time.Second, "colima-status", "health"); rc == 0 {
			sock, _ := runCmdOut(2*time.Second, "colima-status", "socket")
			s.passLine(fmt.Sprintf("Colima  healthy (%s)", strings.TrimSpace(sock)))
		} else {
			sock, _ := runCmdOut(2*time.Second, "colima-status", "socket")
			sock = strings.TrimSpace(sock)
			if sock != "" {
				s.warnLine(fmt.Sprintf("Colima  socket present but not healthy (%s)", sock))
			} else {
				s.warnLine("Colima  not running")
			}
			s.fix("zsvc start colima")
		}
	} else {
		s.warnLine("Colima  colima-status not found — cannot verify")
	}

	if info, err := os.Stat(filepath.Join(cfg.home, ".aider")); err == nil && info.IsDir() {
		s.warnLine(fmt.Sprintf("%s/.aider  present — aider config should live in $XDG_CONFIG_HOME/aider", cfg.home))
		s.fix(fmt.Sprintf(`mv %s/.aider "${XDG_CONFIG_HOME:-$HOME/.config}/aider"`, cfg.home))
	} else {
		s.passLine(fmt.Sprintf("%s/.aider  absent", cfg.home))
	}

	xdgCfg := envOr("XDG_CONFIG_HOME", filepath.Join(cfg.home, ".config"))
	if d1, e1 := os.Stat(filepath.Join(cfg.home, ".pi")); e1 == nil && d1.IsDir() {
		if d2, e2 := os.Stat(filepath.Join(xdgCfg, "pi")); e2 == nil && d2.IsDir() {
			s.warnLine(fmt.Sprintf("%s/.pi  and XDG pi config both present — potential conflict", cfg.home))
			return s
		}
	}
	s.passLine(fmt.Sprintf("%s/.pi  no XDG conflict", cfg.home))
	return s
}

func checkAITools(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "AI tools"}
	piAgent := filepath.Join(cfg.home, ".pi", "agent")
	_, piErr := exec.LookPath("pi")
	_, piDirErr := os.Stat(piAgent)
	piInstalled := piErr == nil || piDirErr == nil

	if !piInstalled {
		s.skip("Pi  not installed (no pi on PATH, no ~/.pi/agent)")
	} else if data, err := os.ReadFile(filepath.Join(piAgent, "settings.json")); err == nil {
		var doc struct {
			DefaultThinkingLevel string `json:"defaultThinkingLevel"`
		}
		thinking := "unset"
		if json.Unmarshal(data, &doc) == nil && doc.DefaultThinkingLevel != "" {
			thinking = doc.DefaultThinkingLevel
		}
		if thinking == "off" {
			s.passLine("Pi settings  defaultThinkingLevel=off")
		} else {
			s.warnLine(fmt.Sprintf("Pi settings  defaultThinkingLevel=%s (should be off — burns 32k context on 7B)", thinking))
			s.fix("zdots-update-local  (reconciles Pi settings)")
		}
	} else {
		s.warnLine("Pi settings  ~/.pi/agent/settings.json missing")
		s.fix("zdots-update-local")
	}

	if !piInstalled {
		// Reported once above.
	} else if data, err := os.ReadFile(filepath.Join(piAgent, "models.json")); err == nil {
		var doc struct {
			Providers struct {
				Llamacpp struct {
					BaseURL string `json:"baseUrl"`
				} `json:"llamacpp"`
			} `json:"providers"`
		}
		if json.Unmarshal(data, &doc) == nil && doc.Providers.Llamacpp.BaseURL != "" {
			s.passLine("Pi models  endpoint " + doc.Providers.Llamacpp.BaseURL)
		} else {
			s.warnLine("Pi models  models.json present but no llamacpp baseUrl")
			s.fix("zdots-update-local")
		}
	} else {
		s.warnLine("Pi models  ~/.pi/agent/models.json missing")
		s.fix("zdots-update-local")
	}

	aiderMeta := filepath.Join(cfg.home, ".aider.model.metadata.json")
	if data, err := os.ReadFile(aiderMeta); err == nil {
		var doc map[string]struct {
			MaxInputTokens any `json:"max_input_tokens"`
		}
		if json.Unmarshal(data, &doc) == nil {
			if entry, ok := doc["openai/local"]; ok && entry.MaxInputTokens != nil {
				s.passLine(fmt.Sprintf("Aider metadata  context_window=%v", entry.MaxInputTokens))
			} else {
				s.warnLine("Aider metadata  present but missing openai/local entry")
				s.fix("zdots-update-local")
			}
		} else {
			s.warnLine("Aider metadata  present but missing openai/local entry")
			s.fix("zdots-update-local")
		}
	} else {
		s.warnLine("Aider metadata  ~/.aider.model.metadata.json missing")
		s.fix("zdots-update-local")
	}

	aiderBin, _ := exec.LookPath("aider")
	if aiderBin == "" {
		cand := filepath.Join(cfg.home, ".local", "share", "uv", "tools", "aider-chat", "bin", "aider")
		if info, err := os.Stat(cand); err == nil && !info.IsDir() {
			aiderBin = cand
		}
	}
	if aiderBin != "" {
		s.passLine("aider  " + aiderBin)
	} else {
		s.skip("aider  not installed (optional)")
	}

	if gBin, err := exec.LookPath("gemini"); err == nil {
		s.passLine("gemini CLI  " + gBin)
	} else {
		s.skip("gemini CLI  not installed (optional)")
	}
	return s
}

func checkGH(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "GitHub insights (zdots-gh)"}
	zghPath := filepath.Join(cfg.binDir, "zdots-gh")
	info, err := os.Stat(zghPath)
	if err != nil || info.IsDir() || (info.Mode()&0o111) == 0 {
		s.skip("zdots-gh  not present (optional GitHub delivery-insights tool)")
		return s
	}

	var missingAssets []string
	for _, a := range []string{"warehouse.sql", "insights.rb", "insights-catalog.yaml", "report.py"} {
		if _, err := os.Stat(filepath.Join(cfg.zdotdir, "etc", "zdots-gh", a)); err != nil {
			missingAssets = append(missingAssets, a)
		}
	}
	if len(missingAssets) == 0 {
		s.passLine("zdots-gh  present, assets complete")
	} else {
		s.failLine("zdots-gh  assets missing: " + strings.Join(missingAssets, " "))
		s.fix(fmt.Sprintf("git -C %s checkout -- etc/zdots-gh", cfg.zdotdir))
	}

	var missingDeps []string
	for _, d := range []string{"gh", "duckdb", "ruby", "jq"} {
		if _, err := exec.LookPath(d); err != nil {
			missingDeps = append(missingDeps, d)
		}
	}
	if len(missingDeps) == 0 {
		s.passLine("zdots-gh deps  gh, duckdb, ruby, jq present")
	} else {
		s.warnLine("zdots-gh deps  missing: " + strings.Join(missingDeps, " ") + " — 'zdots-gh run' will fail")
		s.fix("brew bundle  (gh, duckdb); ensure ruby on PATH")
	}

	if _, err := exec.LookPath("ruby"); err == nil {
		catPath := filepath.Join(cfg.zdotdir, "etc", "zdots-gh", "insights-catalog.yaml")
		if _, rc := runCmdOut(4*time.Second, "ruby", "-ryaml", "-e", "YAML.load_file(ARGV[0])", catPath); rc == 0 {
			s.passLine("insights catalog  valid YAML")
		} else {
			s.failLine("insights catalog  invalid — the insights report will degrade")
			s.fix(`ruby -ryaml -e 'YAML.load_file("etc/zdots-gh/insights-catalog.yaml")'`)
		}
	}

	zghState := envOr("ZDOTS_GH_STATE", filepath.Join(cfg.xdgState, "zdots", "gh"))
	if entries, err := os.ReadDir(zghState); err == nil {
		owners := 0
		for _, e := range entries {
			if e.IsDir() && e.Name() != "reports" {
				owners++
			}
		}
		s.ok(fmt.Sprintf("zdots-gh cache  %d owner(s) under %s", owners, zghState))
	} else {
		s.skip("zdots-gh cache  none yet — run: zdots-gh run <org-or-user>")
	}
	return s
}

func checkWork(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Work machine"}
	if key := os.Getenv("ZDOTS_DB_ENCRYPTION_KEY"); key != "" {
		s.passLine(fmt.Sprintf("ZDOTS_DB_ENCRYPTION_KEY  set (%d chars)", len(key)))
	} else {
		s.failLine("ZDOTS_DB_ENCRYPTION_KEY  not set — required for PHI work")
		s.fix("zdots-keychain add ZDOTS_DB_ENCRYPTION_KEY <value>")
	}

	if envOr("ZDOTS_HISTORY_REDACT", "1") == "1" {
		s.passLine("history redaction  enabled")
	} else {
		s.failLine("history redaction  DISABLED on work machine (ZDOTS_HISTORY_REDACT=0)")
	}

	aiMode := envOr("ZDOTS_AI_MODE", "local")
	if aiMode == "local" || aiMode == "none" {
		s.passLine(fmt.Sprintf("AI mode  %s (no cloud endpoints)", aiMode))
	} else {
		s.warnLine(fmt.Sprintf("AI mode  %s — cloud endpoints active on work machine", aiMode))
	}

	if out, rc := runCmdOut(3*time.Second, "fdesetup", "status"); rc == 0 && strings.Contains(out, "FileVault is On") {
		s.passLine("FileVault  enabled")
	} else {
		s.failLine("FileVault  NOT enabled — required for PHI work")
		s.fix("sudo fdesetup enable")
	}
	return s
}

func checkServices(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Services"}
	s.raw(zsvc.ListText(cfg.zdotdir))

	candidates := []string{
		"llama-server", "llama-embed", "otel-collector", "worker", "statusd",
		"gemstash", "log-rotate", "embed-tripwire", "colima-autostart",
	}
	aiMode := envOr("ZDOTS_AI_MODE", "local")
	var expected []string
	for _, lc := range candidates {
		plist := filepath.Join(cfg.home, "Library", "LaunchAgents", fmt.Sprintf("com.zdots.%s.plist", lc))
		if (lc == "llama-server" && aiMode == "local") || fileExists(plist) {
			expected = append(expected, lc)
		}
	}

	lcOut, _ := runCmdOut(3*time.Second, "launchctl", "list")
	var zdotsLines []string
	loadedLabels := make(map[string]bool)
	var pids []string
	for _, line := range strings.Split(lcOut, "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 3 && strings.HasPrefix(fields[2], "com.zdots.") {
			zdotsLines = append(zdotsLines, line)
			loadedLabels[fields[2]] = true
			if _, err := strconv.Atoi(fields[0]); err == nil {
				pids = append(pids, fields[0])
			}
		}
	}

	lcMissing := false
	for _, lc := range expected {
		lbl := "com.zdots." + lc
		if !loadedLabels[lbl] {
			lcMissing = true
			s.warnLine(fmt.Sprintf("launchd manifest  %s not loaded — install-set drift", lbl))
			s.fix(fmt.Sprintf("launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/%s.plist  (reinstall via its ctl if the plist is gone)", lbl))
		}
	}
	if !lcMissing {
		s.passLine(fmt.Sprintf("launchd manifest  all %d provisioned com.zdots labels loaded", len(expected)))
	}

	uid := strconv.Itoa(os.Getuid())
	lcFlap := false
	for _, line := range zdotsLines {
		fields := strings.Fields(line)
		lbl := fields[2]
		lp, rc := runCmdOut(2*time.Second, "launchctl", "print", fmt.Sprintf("gui/%s/%s", uid, lbl))
		if rc != 0 {
			continue
		}
		lastExit := ""
		runs := ""
		for _, pl := range strings.Split(lp, "\n") {
			if lastExit == "" && strings.Contains(pl, "last exit code = ") {
				parts := strings.Fields(pl)
				lastExit = parts[len(parts)-1]
			}
			if runs == "" && strings.Contains(pl, "runs = ") {
				parts := strings.Fields(pl)
				runs = parts[len(parts)-1]
			}
		}
		if code, err := strconv.Atoi(lastExit); err == nil && code != 0 {
			lcFlap = true
			if runs == "" {
				runs = "?"
			}
			s.warnLine(fmt.Sprintf("launchd flap  %s last exit code %d (runs=%s)", lbl, code, runs))
			s.fix("zsvc diag " + strings.TrimPrefix(lbl, "com.zdots."))
		}
	}
	if !lcFlap {
		s.passLine("launchd flap  no com.zdots service exited non-zero")
	}

	if len(pids) > 0 {
		lsofOut, _ := runCmdOut(4*time.Second, "lsof", "-a", "-nP", "+c", "0", "+L1", "-p", strings.Join(pids, ","))
		homePrefix := cfg.home + "/"
		seen := make(map[string]bool)
		counts := make(map[string]int)
		examples := make(map[string]string)
		var keys []string
		for idx, line := range strings.Split(lsofOut, "\n") {
			if idx == 0 || strings.TrimSpace(line) == "" {
				continue
			}
			fields := strings.Fields(line)
			if len(fields) < 10 {
				continue
			}
			p := strings.Join(fields[9:], " ")
			if !(strings.HasPrefix(p, homePrefix) || strings.HasPrefix(p, "/opt/")) {
				continue
			}
			dedup := fields[1] + "|" + p
			if seen[dedup] {
				continue
			}
			seen[dedup] = true
			k := fmt.Sprintf("%s (pid %s)", fields[0], fields[1])
			if counts[k] == 0 {
				keys = append(keys, k)
				examples[k] = p
			}
			counts[k]++
		}
		if len(keys) > 0 {
			for _, k := range keys {
				s.warnLine(fmt.Sprintf("dead inode  %s holds %d deleted file(s), e.g. %s — on-disk state diverged; restart will lose it", k, counts[k], examples[k]))
			}
			s.fix("lsof -a +L1 -p <pid> for the full list; verify the install (e.g. brew reinstall) before any restart")
		} else {
			s.passLine("dead inodes  none held under $HOME or /opt by com.zdots pids")
		}
	}
	return s
}

func checkInference(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "AI inference"}
	aiEP := config.Load(cfg.zdotdir).AIEndpoint()
	aiLog := filepath.Join(cfg.stateDir, "llama-server.log")

	healthClient := &http.Client{Timeout: 3 * time.Second}
	if resp, err := healthClient.Get(aiEP + "/health"); err == nil && resp.StatusCode >= 200 && resp.StatusCode < 300 {
		_ = resp.Body.Close()
		inferClient := &http.Client{Timeout: 20 * time.Second}
		payload := []byte(`{"model":"local","messages":[{"role":"user","content":"hi"}],"max_tokens":1}`)
		req, _ := http.NewRequest(http.MethodPost, aiEP+"/v1/chat/completions", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		if iresp, err := inferClient.Do(req); err == nil {
			var buf bytes.Buffer
			_, _ = buf.ReadFrom(iresp.Body)
			_ = iresp.Body.Close()
			if strings.Contains(buf.String(), `"content"`) {
				s.passLine(fmt.Sprintf("inference  first token ok (%s)", aiEP))
			} else {
				s.failLine("inference  server up but not responding to chat requests")
				if data, err := os.ReadFile(aiLog); err == nil && strings.Contains(string(data), "kIOGPUCommandBufferCallbackErrorOutOfMemory") {
					s.fix("GPU OOM in logs — disable speculative decoding: comment out draft_model_file in etc/ai-models.yaml then: llama-ctl install")
				} else {
					s.fix("zsvc logs llama  (check for startup errors)")
					s.fix("zsvc restart llama")
				}
			}
		} else {
			s.failLine("inference  server up but not responding to chat requests")
			s.fix("zsvc logs llama  (check for startup errors)")
			s.fix("zsvc restart llama")
		}
	} else {
		if resp != nil {
			_ = resp.Body.Close()
		}
		s.skip("inference  server not running (skipped)")
	}

	twLog := filepath.Join(cfg.stateDir, "embed-model-tripwire.log")
	if info, err := os.Stat(twLog); err == nil && info.Size() > 0 {
		snaps := 0
		if data, err := os.ReadFile(twLog); err == nil {
			for _, line := range strings.Split(string(data), "\n") {
				if strings.HasPrefix(line, "=== ") {
					snaps++
				}
			}
		}
		s.warnLine(fmt.Sprintf("embed-model tripwire  FIRED — deleter evidence captured (%d snapshot(s))", snaps))
		s.fix(fmt.Sprintf("read it: less %s   then attach findings to backlog Z-260", twLog))
	} else {
		s.passLine("embed-model tripwire  quiet (no deletion since armed)")
	}
	return s
}

func checkObservability(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Observability"}
	otelCfg := filepath.Join(cfg.zdotdir, "etc", "otel-collector.yaml")
	if data, err := os.ReadFile(otelCfg); err == nil {
		txt := string(data)
		retiredRe := regexp.MustCompile(`(?i)otlp_?http/(openobserve|lgtm)|exporters:.*lgtm`)
		if strings.Contains(txt, "file/logs:") && strings.Contains(txt, "file/metrics:") && !retiredRe.MatchString(txt) {
			s.passLine("collector  exports to rotated local files")
		} else {
			s.warnLine("collector  config still references retired O2/LGTM exporter")
			s.fix("route etc/otel-collector.yaml pipelines to rotated local file exporters")
		}
	}
	return s
}

func checkLogs(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Log sizes"}
	out, rc := logs.CheckText()
	s.raw(out)
	if rc != 0 {
		if strings.Contains(out, "CRITICAL") {
			s.failLine("log files exceed 500M threshold — consider log rotation (logrotate or truncation)")
			s.fix("zdots-logs list  (see sizes and growth estimates)")
			s.fix("zdots-logs check --json  (machine-readable with projections)")
		} else {
			s.failLine(fmt.Sprintf("zdots-logs check errored (rc=%d) — log sizes UNVERIFIED", rc))
			s.fix("run: zdots-logs check  (inspect the error; see also Z-282 cwd-dependent PATH)")
		}
	} else if strings.Contains(out, "** WARNING") {
		s.warnLine("log files approaching size threshold — monitor for growth")
	} else {
		s.passLine("all log files within size thresholds")
	}
	return s
}

func checkRuntime(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Runtime health  (zdots-ctl check)"}
	if cfg.skipRuntime {
		s.skip("skipped  (--no-runtime)")
		return s
	}
	out, rc := ctl.CheckText(cfg.zdotdir)
	s.runtimeRC = rc
	addRuntimeOutput(s, out)
	return s
}

// runtimeWarnRe matches a zdots-ctl check warning line ("  [WARN] label  detail").
var runtimeWarnRe = regexp.MustCompile(`^\s*\[WARN\]\s+(.+?)\s*$`)

// addRuntimeOutput records zdots-ctl check output: each [WARN] line becomes a
// warning (so a host accept list can match it); other lines stay raw. When the
// output has no [WARN] lines, the summary's warning count is used instead.
func addRuntimeOutput(s *sectionResult, out string) {
	warnLines := 0
	for _, line := range strings.Split(strings.TrimRight(out, "\n"), "\n") {
		if m := runtimeWarnRe.FindStringSubmatch(line); m != nil {
			s.warnLine(m[1])
			warnLines++
		} else {
			s.raw(line)
		}
	}
	warnRe := regexp.MustCompile(`([0-9]+) warning`)
	failRe := regexp.MustCompile(`([0-9]+) failure`)
	if matches := warnRe.FindAllStringSubmatch(out, -1); len(matches) > 0 && warnLines == 0 {
		if n, err := strconv.Atoi(matches[len(matches)-1][1]); err == nil {
			s.warn += n
		}
	}
	if matches := failRe.FindAllStringSubmatch(out, -1); len(matches) > 0 {
		if n, err := strconv.Atoi(matches[len(matches)-1][1]); err == nil {
			s.fail += n
		}
	}
}

func checkPeer(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Peer dependencies (adots)"}
	if os.Getenv("_DOCTOR_PEER") != "" {
		s.skip("adots-doctor  peer check skipped (already inside a peer-health chain)")
	} else if _, err := exec.LookPath("adots-doctor"); err == nil {
		out, rc := runCmdEnvOut(10*time.Second, []string{"_DOCTOR_PEER=1"}, "adots-doctor")
		s.adotsRC = rc
		if rc == 0 {
			s.passLine("adots-doctor  healthy")
		} else {
			s.warnLine(fmt.Sprintf("adots-doctor  returned exit code %d — check with: adots-doctor --fix", rc))
			if !cfg.quiet && out != "" {
				var indented []string
				for _, ln := range strings.Split(strings.TrimRight(out, "\n"), "\n") {
					indented = append(indented, "             "+ln)
				}
				s.raw(strings.Join(indented, "\n"))
			}
		}
	} else {
		s.skip("adots-doctor  not found (optional peer; home blanket tracking disabled)")
	}
	return s
}

func checkGitHooks(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Git hooks alignment"}
	repos := []string{
		cfg.zdotdir,
		filepath.Join(cfg.home, ".config", "nvim"),
		filepath.Join(cfg.home, "github.com", "just3ws", "ztranscribe"),
		filepath.Join(cfg.home, "github.com", "just3ws", "just3ws.github.io"),
	}
	for _, repo := range repos {
		if info, err := os.Stat(filepath.Join(repo, ".git")); err != nil || !info.IsDir() {
			continue
		}
		rname := filepath.Base(repo)
		hp, _ := runCmdOut(2*time.Second, "git", "-C", repo, "config", "--get", "core.hooksPath")
		hp = strings.TrimSpace(hp)
		if hp == ".githooks" {
			s.passLine(fmt.Sprintf("hooks  %s (core.hooksPath=.githooks)", rname))
		} else {
			if hp == "" {
				hp = "unset"
			}
			s.warnLine(fmt.Sprintf("hooks  %s core.hooksPath='%s' (expected .githooks)", rname, hp))
			s.fix(fmt.Sprintf("git -C %s config core.hooksPath .githooks", repo))
		}
	}
	return s
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

// acceptEntry is one line of a host's doctor accept list: warnings whose text
// starts with prefix (with $HOME written as ~) are expected on this host.
type acceptEntry struct{ prefix, reason string }

// acceptFile is the host's accept list: ZDOTS_DOCTOR_ACCEPT_FILE, or the
// gitignored $ZDOTDIR/.zdots.doctor-accept.
func acceptFile(cfg envConfig) string {
	return envOr("ZDOTS_DOCTOR_ACCEPT_FILE", filepath.Join(cfg.zdotdir, ".zdots.doctor-accept"))
}

// loadAccepts reads "prefix  # reason" lines; blank lines and # comments are
// skipped. A missing file means nothing is accepted.
func loadAccepts(path string) []acceptEntry {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var out []acceptEntry
	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		prefix, reason, _ := strings.Cut(line, "#")
		prefix = strings.TrimSpace(prefix)
		if prefix != "" {
			out = append(out, acceptEntry{prefix: prefix, reason: strings.TrimSpace(reason)})
		}
	}
	return out
}

// applyAccepts turns accepted warnings into [accept] lines so they no longer
// count as warnings, and returns how many it accepted. Failures are never
// accepted.
func applyAccepts(results []*sectionResult, accepts []acceptEntry, home string) int {
	if len(accepts) == 0 {
		return 0
	}
	n := 0
	for _, r := range results {
		if r == nil {
			continue
		}
		kept := r.lines[:0]
		dropFix := false
		for _, l := range r.lines {
			if l.kind == kindFix && dropFix {
				continue // the fix hint of an accepted warning
			}
			dropFix = false
			if l.kind != kindWarn {
				kept = append(kept, l)
				continue
			}
			text := l.text
			if home != "" {
				text = strings.ReplaceAll(text, home, "~")
			}
			accepted := false
			for _, a := range accepts {
				if !strings.HasPrefix(text, a.prefix) {
					continue
				}
				note := " — accepted"
				if a.reason != "" {
					note += ": " + a.reason
				}
				kept = append(kept, lineItem{kindAccept, text + note})
				r.warn--
				r.accepted++
				n++
				accepted, dropFix = true, true
				break
			}
			if !accepted {
				kept = append(kept, l)
			}
		}
		r.lines = kept
	}
	return n
}
