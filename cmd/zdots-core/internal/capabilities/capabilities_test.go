package capabilities

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadEnvWithManifest(t *testing.T) {
	dir := t.TempDir()
	manifest := filepath.Join(dir, ".zdots.env")
	err := os.WriteFile(manifest, []byte(`
# comment
export ZDOTS_ENV_PROFILE="work"
ZDOTS_SERVICE_AI='local'
ZDOTS_SERVICE_WHISPER=none
`), 0o600)
	if err != nil {
		t.Fatal(err)
	}

	env := loadEnvWithManifest(manifest)
	if env["ZDOTS_ENV_PROFILE"] != "work" {
		t.Fatalf("got profile %q, want work", env["ZDOTS_ENV_PROFILE"])
	}
	if env["ZDOTS_SERVICE_AI"] != "local" {
		t.Fatalf("got ai %q, want local", env["ZDOTS_SERVICE_AI"])
	}
	if env["ZDOTS_SERVICE_WHISPER"] != "none" {
		t.Fatalf("got whisper %q, want none", env["ZDOTS_SERVICE_WHISPER"])
	}
}

func TestReadLastTraceTS(t *testing.T) {
	dir := t.TempDir()
	tf := filepath.Join(dir, "traces.jsonl")
	err := os.WriteFile(tf, []byte("{\"ts\":\"2026-11-15T10:00:00-0600\",\"cmd\":\"ls\"}\n"), 0o600)
	if err != nil {
		t.Fatal(err)
	}

	ts, age := readLastTraceTS(tf)
	if ts != "2026-11-15T10:00:00-0600" {
		t.Fatalf("got ts %q", ts)
	}
	if age == "unknown" {
		t.Fatalf("expected numeric age, got unknown")
	}
}

func TestRunHelpAndUnknownFlag(t *testing.T) {
	if code := Run([]string{"--help"}); code != 0 {
		t.Fatalf("--help exited %d, want 0", code)
	}
	if code := Run([]string{"--bogus"}); code != 1 {
		t.Fatalf("--bogus exited %d, want 1", code)
	}
}
