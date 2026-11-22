package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadPrecedence(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "etc"), 0o755); err != nil {
		t.Fatal(err)
	}
	defaults := `
# comment
export ZDOTS_AI_PORT="${ZDOTS_AI_PORT:-11500}"
export ZDOTS_O2_PORT="${ZDOTS_O2_PORT:-5080}"
export ZDOTS_REDIS_PORT="${ZDOTS_REDIS_PORT:-6379}"
`
	if err := os.WriteFile(filepath.Join(dir, "etc", "defaults.env"), []byte(defaults), 0o600); err != nil {
		t.Fatal(err)
	}
	manifest := `
export ZDOTS_O2_PORT="${ZDOTS_O2_PORT:-5081}"
if [ "$FOO" = "bar" ]; then
  export ZDOTS_REDIS_PORT="9999"
fi
`
	if err := os.WriteFile(filepath.Join(dir, ".zdots.env"), []byte(manifest), 0o600); err != nil {
		t.Fatal(err)
	}

	t.Setenv("ZDOTS_AI_PORT", "19999")
	t.Setenv("ZDOTS_O2_PORT", "")
	t.Setenv("ZDOTS_REDIS_PORT", "")

	env := Load(dir)
	if got := env.Get("ZDOTS_AI_PORT", ""); got != "19999" {
		t.Fatalf("process env should win: got %q, want 19999", got)
	}
	if got := env.Get("ZDOTS_O2_PORT", ""); got != "5081" {
		t.Fatalf(".zdots.env should override defaults.env: got %q, want 5081", got)
	}
	if got := env.Get("ZDOTS_REDIS_PORT", ""); got != "6379" {
		t.Fatalf("defaults.env should fill unset key (ignoring conditional block): got %q, want 6379", got)
	}
	if got := env.Get("NONEXISTENT_KEY", "fallback"); got != "fallback" {
		t.Fatalf("fallback failed: got %q", got)
	}
}
