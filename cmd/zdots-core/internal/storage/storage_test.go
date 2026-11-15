package storage

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseNonNegInt(t *testing.T) {
	if v, err := parseNonNegInt("45"); err != nil || v != 45 {
		t.Fatalf("got (%d, %v), want (45, nil)", v, err)
	}
	if _, err := parseNonNegInt("unlimited"); err == nil {
		t.Fatal("expected error for unlimited")
	}
	if _, err := parseNonNegInt("-1"); err == nil {
		t.Fatal("expected error for -1")
	}
}

func TestActiveModelFile(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "ai-models.yaml")
	err := os.WriteFile(p, []byte(`
default_profile: qwen3-8b
profiles:
  other:
    model_file: "other.gguf"
  qwen3-8b:
    model_file: "Qwen3-8B.gguf"
`), 0o600)
	if err != nil {
		t.Fatal(err)
	}
	if got := activeModelFile(p); got != "Qwen3-8B.gguf" {
		t.Fatalf("got %q, want Qwen3-8B.gguf", got)
	}
}

func TestRunHelpAndBadReserve(t *testing.T) {
	if code := Run([]string{"--help"}); code != 0 {
		t.Fatalf("--help exited %d, want 0", code)
	}
	t.Setenv("ZDOTS_STORAGE_RESERVE_GB", "unlimited")
	if code := Run([]string{"--json"}); code != 2 {
		t.Fatalf("bad reserve exited %d, want 2", code)
	}
}
