package llamacaps

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseModelsYAMLAndLoadConfig(t *testing.T) {
	tmp := t.TempDir()
	etcDir := filepath.Join(tmp, "etc")
	if err := os.MkdirAll(etcDir, 0o755); err != nil {
		t.Fatal(err)
	}
	yamlBody := `
profiles:
  qwen3-8b:
    model_file: "Qwen_Qwen3-8B-Q4_K_M.gguf"
    ctx_size: 32768
  work-light:
    model_file: "Qwen_Qwen3-4B.gguf"
    ctx_size: 16384

default_profile: "qwen3-8b"

server:
  parallel: 1 # inline comment
  batch_size: 2048
  ubatch_size: 2048
  cache_type_k: q8_0
  cache_type_v: q8_0
  n_predict: -1
  alias: "local"
  embeddings: false
  flash_attn: true
  metrics: true
`
	if err := os.WriteFile(filepath.Join(etcDir, "ai-models.yaml"), []byte(yamlBody), 0o644); err != nil {
		t.Fatal(err)
	}

	cfg := loadConfig(tmp, "", "")
	if cfg.Profile != "qwen3-8b" {
		t.Fatalf("expected profile qwen3-8b, got %q", cfg.Profile)
	}
	if cfg.ModelFile != "Qwen_Qwen3-8B-Q4_K_M.gguf" {
		t.Fatalf("expected model_file Qwen_Qwen3-8B-Q4_K_M.gguf, got %q", cfg.ModelFile)
	}
	if cfg.ContextWindow != 32768 || cfg.ParallelSlots != 1 || cfg.UbatchSize != 2048 {
		t.Fatalf("unexpected numeric config: %+v", cfg)
	}
	if !cfg.FlashAttn || !cfg.MetricsEnabled || cfg.EmbeddingsEnabled {
		t.Fatalf("unexpected bool config: %+v", cfg)
	}
	if cfg.MaxEmbedTokens != 2048 || cfg.MaxEmbedWords != 1536 {
		t.Fatalf("unexpected embed math: %+v", cfg)
	}

	cfgOverride := loadConfig(tmp, "http://127.0.0.1:19999", "work-light")
	if cfgOverride.Profile != "work-light" || cfgOverride.ContextWindow != 16384 || cfgOverride.Endpoint != "http://127.0.0.1:19999" {
		t.Fatalf("unexpected override config: %+v", cfgOverride)
	}
}

func TestRunJSONAndMarkdownWithMockHealth(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`{"status":"ok"}`))
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()

	t.Setenv("ZDOTS_AI_ENDPOINT", srv.URL)

	var jsonBuf, errBuf bytes.Buffer
	code := runWithWriters([]string{"--json"}, &jsonBuf, &errBuf)
	if code != 0 {
		t.Fatalf("expected exit 0, got %d (stderr=%s)", code, errBuf.String())
	}

	var doc map[string]any
	if err := json.Unmarshal(jsonBuf.Bytes(), &doc); err != nil {
		t.Fatalf("invalid json output: %v\n%s", err, jsonBuf.String())
	}
	if doc["$schema"] != "zdots/llama-caps/v1" {
		t.Fatalf("unexpected schema: %v", doc["$schema"])
	}
	serverMap, ok := doc["server"].(map[string]any)
	if !ok || serverMap["health"] != "ok" {
		t.Fatalf("expected server.health == ok, got %v", doc["server"])
	}

	var mdBuf bytes.Buffer
	errBuf.Reset()
	code = runWithWriters([]string{"--md"}, &mdBuf, &errBuf)
	if code != 0 {
		t.Fatalf("expected exit 0 for --md, got %d", code)
	}
	if !strings.Contains(mdBuf.String(), "# llama.cpp Local Inference — Capability Reference") {
		t.Fatalf("missing markdown header in output")
	}
	if !strings.Contains(mdBuf.String(), "Status: **ok**") {
		t.Fatalf("expected ok health in markdown output")
	}
}
