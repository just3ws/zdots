package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHelpAndUnknownFlag(t *testing.T) {
	if rc := Run([]string{"--help"}); rc != 0 {
		t.Fatalf("--help returned %d, want 0", rc)
	}
	if rc := Run([]string{"--bogus-flag"}); rc != 1 {
		t.Fatalf("--bogus-flag returned %d, want 1", rc)
	}
}

func TestJSONOutputAndTraceLog(t *testing.T) {
	tmp := t.TempDir()
	xdgState := filepath.Join(tmp, "state")
	zdotdir := filepath.Join(tmp, "zdots")
	_ = os.MkdirAll(filepath.Join(zdotdir, "bin"), 0o755)
	_ = os.MkdirAll(filepath.Join(zdotdir, "etc"), 0o755)
	_ = os.WriteFile(filepath.Join(zdotdir, "VERSION"), []byte("0873026.M3\n"), 0o644)
	_ = os.WriteFile(filepath.Join(zdotdir, "etc", "otel-collector.yaml"), []byte("exporters:\n  file/logs:\n  file/metrics:\n"), 0o644)

	t.Setenv("ZDOTDIR", zdotdir)
	t.Setenv("XDG_STATE_HOME", xdgState)
	t.Setenv("ZDOTS_NO_OTEL", "1")
	t.Setenv("ZDOTS_CONTEXT", "home")
	t.Setenv("_DOCTOR_PEER", "1")
	t.Setenv("HOMEBREW_PREFIX", "/opt/homebrew")

	// Capture stdout
	oldStdout := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = w

	rc := Run([]string{"--no-runtime", "--json"})

	_ = w.Close()
	os.Stdout = oldStdout

	var buf [16384]byte
	n, _ := r.Read(buf[:])
	_ = r.Close()
	out := string(buf[:n])

	var rep jsonReport
	if err := json.Unmarshal([]byte(out), &rep); err != nil {
		t.Fatalf("invalid JSON output: %v\noutput=%s", err, out)
	}
	if rep.Status != "pass" && rep.Status != "fail" {
		t.Fatalf("unexpected status: %q", rep.Status)
	}
	if rc < 0 {
		t.Fatalf("unexpected negative rc: %d", rc)
	}

	traceBytes, err := os.ReadFile(filepath.Join(xdgState, "zsh", "traces.jsonl"))
	if err != nil {
		t.Fatalf("expected traces.jsonl to be written: %v", err)
	}
	if !strings.Contains(string(traceBytes), `"event":"doctor_check"`) {
		t.Fatalf("expected doctor_check event in traces.jsonl, got %s", string(traceBytes))
	}
}

func TestLoadAcceptsParsesPrefixesAndReasons(t *testing.T) {
	path := filepath.Join(t.TempDir(), "accept")
	body := "# host accept list\n\n~/.zshrc  # employer baseline owns it\nmkcert CA\n"
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	got := loadAccepts(path)
	if len(got) != 2 {
		t.Fatalf("got %d entries, want 2: %+v", len(got), got)
	}
	if got[0].prefix != "~/.zshrc" || got[0].reason != "employer baseline owns it" {
		t.Fatalf("entry 0 = %+v", got[0])
	}
	if got[1].prefix != "mkcert CA" || got[1].reason != "" {
		t.Fatalf("entry 1 = %+v", got[1])
	}
	if loadAccepts(filepath.Join(t.TempDir(), "missing")) != nil {
		t.Fatal("a missing accept file should yield no entries")
	}
}

func TestApplyAcceptsMovesMatchingWarningsOutOfTheCount(t *testing.T) {
	s := &sectionResult{title: "t"}
	s.warnLine("/home/u/.zshrc  present — loaded before ZDOTDIR")
	s.warnLine("mkcert CA  not generated yet")
	s.fix("mkcert-ctl init")
	s.warnLine("Pi models  missing")
	s.fix("zdots-update-local")
	s.failLine("mkcert CA  broken")
	n := applyAccepts([]*sectionResult{s, nil}, []acceptEntry{
		{prefix: "~/.zshrc", reason: "baseline"},
		{prefix: "mkcert CA"},
	}, "/home/u")
	if n != 2 || s.warn != 1 || s.accepted != 2 || s.fail != 1 {
		t.Fatalf("n=%d warn=%d accepted=%d fail=%d, want 2/1/2/1", n, s.warn, s.accepted, s.fail)
	}
	var kinds []lineKind
	for _, l := range s.lines {
		kinds = append(kinds, l.kind)
	}
	want := []lineKind{kindAccept, kindAccept, kindWarn, kindFix, kindFail}
	if len(kinds) != len(want) {
		t.Fatalf("line kinds = %v, want %v (accepted fix hints dropped)", kinds, want)
	}
	for i := range want {
		if kinds[i] != want[i] {
			t.Fatalf("line kinds = %v, want %v", kinds, want)
		}
	}
	if !strings.Contains(s.lines[0].text, "— accepted: baseline") {
		t.Fatalf("accepted line lost its reason: %q", s.lines[0].text)
	}
}

func TestCheckAIToolsSkipsPiWhenNotInstalled(t *testing.T) {
	home := t.TempDir()
	t.Setenv("PATH", t.TempDir())
	s := checkAITools(envConfig{home: home})
	for _, l := range s.lines {
		if l.kind == kindWarn && strings.HasPrefix(l.text, "Pi ") {
			t.Fatalf("pi absent but doctor warned: %q", l.text)
		}
	}
}

func TestAddRuntimeOutputMakesWarnLinesAcceptable(t *testing.T) {
	s := &sectionResult{title: "runtime"}
	addRuntimeOutput(s, "  [PASS] intelligence  connected\n  [WARN] mkcert CA  not generated yet\n  [WARN] OTLP pipeline  skipped\nzdots-ctl check: passed with 2 warning(s)\n")
	if s.warn != 2 {
		t.Fatalf("warn = %d, want 2 (counted once, not twice)", s.warn)
	}
	if n := applyAccepts([]*sectionResult{s}, []acceptEntry{{prefix: "mkcert CA"}}, ""); n != 1 || s.warn != 1 {
		t.Fatalf("accepted=%d warn=%d, want 1/1", n, s.warn)
	}
	s2 := &sectionResult{title: "runtime"}
	addRuntimeOutput(s2, "zdots-ctl check: passed with 3 warning(s)\n")
	if s2.warn != 3 {
		t.Fatalf("summary-only output: warn = %d, want 3", s2.warn)
	}
}
