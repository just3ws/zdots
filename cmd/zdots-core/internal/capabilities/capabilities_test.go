package capabilities

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/config"
)

func TestLoadEnvWithManifest(t *testing.T) {
	for _, k := range []string{"ZDOTS_ENV_PROFILE", "ZDOTS_SERVICE_AI", "ZDOTS_SERVICE_WHISPER"} {
		t.Setenv(k, "")
	}
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

	env := config.LoadFile(manifest)
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

func writeManifest(t *testing.T, body string) string {
	t.Helper()
	manifest := filepath.Join(t.TempDir(), ".zdots.env")
	if err := os.WriteFile(manifest, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	return manifest
}

// The shell has already sourced .zdots.env, so its exported values win.
func TestLoadEnvWithManifestEnvironmentWins(t *testing.T) {
	t.Setenv("ZDOTS_ENV_PROFILE", "macos-standard")
	env := config.LoadFile(writeManifest(t, `export ZDOTS_ENV_PROFILE="ci-act"`))
	if env["ZDOTS_ENV_PROFILE"] != "macos-standard" {
		t.Fatalf("got profile %q, want macos-standard", env["ZDOTS_ENV_PROFILE"])
	}
}

// Conditional assignments depend on shell state the manifest reader cannot
// evaluate, so only top-level lines count.
func TestLoadEnvWithManifestSkipsConditionalBlocks(t *testing.T) {
	for _, k := range []string{"ZDOTS_ENV_PROFILE", "ZDOTS_SERVICE_AI", "ZDOTS_SERVICE_PKG"} {
		t.Setenv(k, "")
	}
	env := config.LoadFile(writeManifest(t, `
export ZDOTS_ENV_PROFILE="macos-standard"
if [ "${ACT:-}" = "true" ]; then
  export ZDOTS_ENV_PROFILE="ci-act"
  if [ -n "$X" ]; then
    export ZDOTS_SERVICE_AI="remote"
  fi
fi
case "$OSTYPE" in
  linux*) export ZDOTS_SERVICE_PKG="apt" ;;
esac
export ZDOTS_SERVICE_AI="local"
`))
	if env["ZDOTS_ENV_PROFILE"] != "macos-standard" {
		t.Fatalf("got profile %q, want macos-standard", env["ZDOTS_ENV_PROFILE"])
	}
	if env["ZDOTS_SERVICE_AI"] != "local" {
		t.Fatalf("got ai %q, want local", env["ZDOTS_SERVICE_AI"])
	}
	if v, ok := env["ZDOTS_SERVICE_PKG"]; ok && v != "" {
		t.Fatalf("got pkg %q, want unset", v)
	}
}

// ${NAME:-default} resolves like the shell; other expansions are not copied
// through as literal text.
func TestLoadEnvWithManifestExpansions(t *testing.T) {
	t.Setenv("ZDOTS_CONTEXT", "")
	t.Setenv("ZDOTS_AI_MODE", "")
	t.Setenv("ZDOTS_MODELS_DIR", "")
	t.Setenv("ZDOTS_SET_ELSEWHERE", "work")
	env := config.LoadFile(writeManifest(t, `
export ZDOTS_CONTEXT="${ZDOTS_CONTEXT:-home}"
export ZDOTS_AI_MODE=${ZDOTS_AI_MODE:-local}
export ZDOTS_SET_ELSEWHERE="${ZDOTS_SET_ELSEWHERE:-home}"
export ZDOTS_MODELS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/models"
`))
	if env["ZDOTS_CONTEXT"] != "home" {
		t.Fatalf("got context %q, want home", env["ZDOTS_CONTEXT"])
	}
	if env["ZDOTS_AI_MODE"] != "local" {
		t.Fatalf("got ai mode %q, want local", env["ZDOTS_AI_MODE"])
	}
	if env["ZDOTS_SET_ELSEWHERE"] != "work" {
		t.Fatalf("got %q, want work", env["ZDOTS_SET_ELSEWHERE"])
	}
	if v := env["ZDOTS_MODELS_DIR"]; v != "" {
		t.Fatalf("got models dir %q, want unset", v)
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
