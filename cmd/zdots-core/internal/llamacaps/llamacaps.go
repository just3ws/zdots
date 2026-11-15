// Package llamacaps implements the llama-caps capability report applet.
package llamacaps

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

type outputFormat int

const (
	formatText outputFormat = iota
	formatJSON
	formatMarkdown
)

// Config holds the resolved llama-server configuration and live health state.
type Config struct {
	Endpoint          string
	Health            string
	Profile           string
	ModelAlias        string
	ModelFile         string
	ContextWindow     int
	ParallelSlots     int
	BatchSize         int
	UbatchSize        int
	CacheTypeK        string
	CacheTypeV        string
	NPredict          int
	EmbeddingsEnabled bool
	FlashAttn         bool
	MetricsEnabled    bool
	MaxEmbedTokens    int
	MaxEmbedWords     int
}

// Run executes the llama-caps applet and returns an exit code.
func Run(args []string) int {
	return runWithWriters(args, os.Stdout, os.Stderr)
}

func runWithWriters(args []string, stdout, stderr io.Writer) int {
	format := formatText
	for _, arg := range args {
		switch arg {
		case "--json":
			format = formatJSON
		case "--md", "--markdown":
			format = formatMarkdown
		case "-h", "--help":
			printUsage(stdout)
			return 0
		}
	}

	tracer := otel.New("llama-caps")
	defer tracer.Flush(250 * time.Millisecond)

	root := tracer.Start("llamacaps.run", nil)
	root.SetAttr("format", formatName(format))

	cfgSpan := tracer.Start("llamacaps.load_config", root)
	cfg := loadConfig(resolveZdotDir(), os.Getenv("ZDOTS_AI_ENDPOINT"), os.Getenv("ZDOTS_AI_PROFILE"))
	cfgSpan.SetAttr("profile", cfg.Profile)
	cfgSpan.SetAttr("model_alias", cfg.ModelAlias)
	cfgSpan.End(true, "")

	probeSpan := tracer.Start("llamacaps.probe_health", root)
	cfg.Health = probeHealth(cfg.Endpoint, 2*time.Second)
	probeSpan.SetAttr("endpoint", cfg.Endpoint)
	probeSpan.SetAttr("health", cfg.Health)
	probeSpan.End(cfg.Health == "ok", "")

	renderSpan := tracer.Start("llamacaps.render", root)
	var err error
	switch format {
	case formatJSON:
		err = renderJSON(stdout, cfg, time.Now().UTC())
	case formatMarkdown:
		err = renderMarkdown(stdout, cfg, time.Now().UTC())
	default:
		err = renderText(stdout, cfg, time.Now())
	}
	if err != nil {
		renderSpan.End(false, err.Error())
		root.End(false, err.Error())
		fmt.Fprintf(stderr, "llama-caps: render error: %v\n", err)
		return 1
	}
	renderSpan.End(true, "")
	root.End(true, "")
	return 0
}

func formatName(f outputFormat) string {
	switch f {
	case formatJSON:
		return "json"
	case formatMarkdown:
		return "md"
	default:
		return "text"
	}
}

func printUsage(w io.Writer) {
	fmt.Fprint(w, `Usage: llama-caps [--json | --md]

  (no flag)   Human-readable terminal report
  --json      Machine-readable JSON capability document
  --md        Markdown — copy to any AI chat (pbcopy, etc.)

Examples:
  llama-caps                # terminal
  llama-caps --md | pbcopy  # brief Gemini/ChatGPT about this stack
  llama-caps --json | jq .capabilities
`)
}

func resolveZdotDir() string {
	if v := os.Getenv("ZDOTDIR"); v != "" {
		return v
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "zsh")
}

func loadConfig(zdotDir, envEndpoint, envProfile string) Config {
	cfg := Config{
		Endpoint:       "http://127.0.0.1:11500",
		Health:         "unreachable",
		Profile:        "standard",
		ModelAlias:     "local",
		ContextWindow:  32768,
		ParallelSlots:  2,
		BatchSize:      2048,
		UbatchSize:     512,
		CacheTypeK:     "f16",
		CacheTypeV:     "f16",
		NPredict:       -1,
		MaxEmbedTokens: 512,
		MaxEmbedWords:  384,
	}
	if envEndpoint != "" {
		cfg.Endpoint = envEndpoint
	}

	raw, err := os.ReadFile(filepath.Join(zdotDir, "etc", "ai-models.yaml"))
	if err == nil {
		parsed := parseModelsYAML(string(raw))
		if envProfile != "" {
			cfg.Profile = envProfile
		} else if parsed.DefaultProfile != "" {
			cfg.Profile = parsed.DefaultProfile
		}

		if p, ok := parsed.Profiles[cfg.Profile]; ok {
			if p.ModelFile != "" {
				cfg.ModelFile = p.ModelFile
			}
			if p.CtxSize > 0 {
				cfg.ContextWindow = p.CtxSize
			}
		}

		if parsed.Server.Alias != "" {
			cfg.ModelAlias = parsed.Server.Alias
		}
		if parsed.Server.Parallel > 0 {
			cfg.ParallelSlots = parsed.Server.Parallel
		}
		if parsed.Server.BatchSize > 0 {
			cfg.BatchSize = parsed.Server.BatchSize
		}
		if parsed.Server.UbatchSize > 0 {
			cfg.UbatchSize = parsed.Server.UbatchSize
		}
		if parsed.Server.CacheTypeK != "" {
			cfg.CacheTypeK = parsed.Server.CacheTypeK
		}
		if parsed.Server.CacheTypeV != "" {
			cfg.CacheTypeV = parsed.Server.CacheTypeV
		}
		if parsed.Server.HasNPredict {
			cfg.NPredict = parsed.Server.NPredict
		}
		cfg.EmbeddingsEnabled = parsed.Server.Embeddings
		cfg.FlashAttn = parsed.Server.FlashAttn
		cfg.MetricsEnabled = parsed.Server.Metrics
	} else if envProfile != "" {
		cfg.Profile = envProfile
	}

	cfg.MaxEmbedTokens = cfg.UbatchSize
	cfg.MaxEmbedWords = cfg.MaxEmbedTokens * 3 / 4
	return cfg
}

type parsedYAML struct {
	DefaultProfile string
	Profiles       map[string]profileYAML
	Server         serverYAML
}

type profileYAML struct {
	ModelFile string
	CtxSize   int
}

type serverYAML struct {
	Alias       string
	Parallel    int
	BatchSize   int
	UbatchSize  int
	CacheTypeK  string
	CacheTypeV  string
	NPredict    int
	HasNPredict bool
	Embeddings  bool
	FlashAttn   bool
	Metrics     bool
}

func parseModelsYAML(content string) parsedYAML {
	out := parsedYAML{
		Profiles: make(map[string]profileYAML),
	}
	section := ""
	currentProfile := ""

	for _, rawLine := range strings.Split(content, "\n") {
		cleaned := stripYAMLComment(rawLine)
		if strings.TrimSpace(cleaned) == "" {
			continue
		}
		indent := len(cleaned) - len(strings.TrimLeft(cleaned, " "))
		trimmed := strings.TrimSpace(cleaned)

		if indent == 0 {
			currentProfile = ""
			k, v, ok := splitKV(trimmed)
			if !ok {
				continue
			}
			switch k {
			case "profiles", "server", "whisper_profiles", "embed_server":
				section = k
			case "default_profile":
				section = ""
				out.DefaultProfile = unquoteYAML(v)
			default:
				section = ""
			}
			continue
		}

		if section == "profiles" {
			if indent == 2 {
				k, v, ok := splitKV(trimmed)
				if ok && v == "" {
					currentProfile = k
					if _, exists := out.Profiles[currentProfile]; !exists {
						out.Profiles[currentProfile] = profileYAML{}
					}
				}
				continue
			}
			if indent >= 4 && currentProfile != "" {
				k, v, ok := splitKV(trimmed)
				if !ok {
					continue
				}
				p := out.Profiles[currentProfile]
				switch k {
				case "model_file":
					p.ModelFile = unquoteYAML(v)
				case "ctx_size":
					if n, err := strconv.Atoi(unquoteYAML(v)); err == nil {
						p.CtxSize = n
					}
				}
				out.Profiles[currentProfile] = p
			}
			continue
		}

		if section == "server" && indent == 2 {
			k, v, ok := splitKV(trimmed)
			if !ok {
				continue
			}
			val := unquoteYAML(v)
			switch k {
			case "alias":
				out.Server.Alias = val
			case "parallel":
				if n, err := strconv.Atoi(val); err == nil {
					out.Server.Parallel = n
				}
			case "batch_size":
				if n, err := strconv.Atoi(val); err == nil {
					out.Server.BatchSize = n
				}
			case "ubatch_size":
				if n, err := strconv.Atoi(val); err == nil {
					out.Server.UbatchSize = n
				}
			case "cache_type_k":
				out.Server.CacheTypeK = val
			case "cache_type_v":
				out.Server.CacheTypeV = val
			case "n_predict":
				if n, err := strconv.Atoi(val); err == nil {
					out.Server.NPredict = n
					out.Server.HasNPredict = true
				}
			case "embeddings":
				out.Server.Embeddings = val == "true"
			case "flash_attn":
				out.Server.FlashAttn = val == "true"
			case "metrics":
				out.Server.Metrics = val == "true"
			}
		}
	}

	return out
}

func stripYAMLComment(line string) string {
	inSingle := false
	inDouble := false
	for i := 0; i < len(line); i++ {
		c := line[i]
		if c == '\'' && !inDouble {
			inSingle = !inSingle
		} else if c == '"' && !inSingle && (i == 0 || line[i-1] != '\\') {
			inDouble = !inDouble
		} else if c == '#' && !inSingle && !inDouble {
			if i == 0 || line[i-1] == ' ' || line[i-1] == '\t' {
				return line[:i]
			}
		}
	}
	return line
}

func splitKV(s string) (string, string, bool) {
	idx := strings.IndexByte(s, ':')
	if idx < 0 {
		return "", "", false
	}
	k := strings.TrimSpace(s[:idx])
	v := strings.TrimSpace(s[idx+1:])
	return k, v, true
}

func unquoteYAML(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 {
		if (s[0] == '"' && s[len(s)-1] == '"') || (s[0] == '\'' && s[len(s)-1] == '\'') {
			return s[1 : len(s)-1]
		}
	}
	return s
}

func probeHealth(endpoint string, timeout time.Duration) string {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(strings.TrimRight(endpoint, "/") + "/health")
	if err != nil {
		return "unreachable"
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return "ok"
	}
	return "unreachable"
}

func renderJSON(w io.Writer, cfg Config, now time.Time) error {
	payload := map[string]any{
		"$schema":      "zdots/llama-caps/v1",
		"generated_at": now.UTC().Format("2006-01-02T15:04:05Z"),
		"server": map[string]any{
			"endpoint":    cfg.Endpoint,
			"health":      cfg.Health,
			"model_alias": cfg.ModelAlias,
			"model_file":  cfg.ModelFile,
			"profile":     cfg.Profile,
			"note":        "Always use model_alias in API calls, never the GGUF filename",
		},
		"config": map[string]any{
			"context_window":        cfg.ContextWindow,
			"parallel_slots":        cfg.ParallelSlots,
			"batch_size":            cfg.BatchSize,
			"ubatch_size":           cfg.UbatchSize,
			"cache_type_k":          cfg.CacheTypeK,
			"cache_type_v":          cfg.CacheTypeV,
			"max_generation_tokens": cfg.NPredict,
			"flash_attention":       cfg.FlashAttn,
		},
		"capabilities": map[string]any{
			"chat": map[string]any{
				"supported":   true,
				"endpoint":    "POST /v1/chat/completions",
				"streaming":   true,
				"system_role": true,
				"tool_use":    true,
				"multi_turn":  true,
				"model_field": cfg.ModelAlias,
			},
			"embeddings": map[string]any{
				"supported":   cfg.EmbeddingsEnabled,
				"endpoint":    "POST /v1/embeddings",
				"batch_input": true,
				"max_tokens":  cfg.MaxEmbedTokens,
				"note":        "ubatch_size is the hard token ceiling per request; exceeding it returns HTTP 500. Run llama-ctl install after changing ubatch_size in ai-models.yaml.",
			},
			"models_list": map[string]any{
				"supported": true,
				"endpoint":  "GET /v1/models",
				"note":      "Returns model_alias as the id, not the GGUF filename",
			},
			"health_check": map[string]any{
				"supported": true,
				"endpoint":  "GET /health",
				"response":  `{"status":"ok"}`,
			},
			"prometheus_metrics": map[string]any{
				"supported": cfg.MetricsEnabled,
				"endpoint":  "GET /metrics",
				"format":    "prometheus text",
			},
			"images": map[string]any{
				"supported": false,
				"reason":    "llama-server does not implement /v1/images/generations",
			},
			"audio_transcription": map[string]any{
				"supported": false,
				"reason":    "No Whisper model loaded; requires a separate server instance with an audio model",
			},
			"moderation": map[string]any{
				"supported": false,
				"reason":    "OpenAI-proprietary endpoint not implemented by llama-server",
			},
		},
		"constraints": map[string]any{
			"auth":                  "None — Bearer token is accepted but ignored. Any non-empty string works.",
			"model_name_rule":       "Use the server alias ('local') in ALL API calls. Never use the GGUF filename. The alias is set via server.alias in etc/ai-models.yaml.",
			"plist_staleness":       "llama-server reads flags from its launchd plist at start time. Changes to ai-models.yaml require llama-ctl install to regenerate the plist, then a server restart.",
			"max_embedding_tokens":  cfg.MaxEmbedTokens,
			"max_generation_tokens": cfg.NPredict,
			"context_window":        cfg.ContextWindow,
			"parallel_slots":        cfg.ParallelSlots,
		},
		"client_integration": map[string]any{
			"ruby_llm": map[string]any{
				"gem": "ruby_llm",
				"configure": map[string]any{
					"openai_api_key":          "<any string — ignored>",
					"openai_api_base":         cfg.Endpoint + "/v1",
					"openai_use_system_role":  true,
					"default_model":           cfg.ModelAlias,
					"default_embedding_model": cfg.ModelAlias,
				},
				"per_call_kwargs": map[string]any{
					"model":               cfg.ModelAlias,
					"provider":            "openai",
					"assume_model_exists": true,
				},
				"critical_note": `RubyLLM validates model IDs against its internal registry of cloud models. The local alias is not in that registry. Pass assume_model_exists: true AND provider: "openai" on EVERY chat/embed call or you will get ModelNotFoundError.`,
			},
			"openai_python_sdk": map[string]any{
				"base_url": cfg.Endpoint + "/v1",
				"api_key":  "<any string>",
				"model":    cfg.ModelAlias,
			},
			"openai_node_sdk": map[string]any{
				"baseURL": cfg.Endpoint + "/v1",
				"apiKey":  "<any string>",
				"model":   cfg.ModelAlias,
			},
			"raw_http": map[string]any{
				"base_url": cfg.Endpoint,
				"required_headers": map[string]any{
					"Content-Type": "application/json",
				},
				"optional_headers": map[string]any{
					"Authorization": "Bearer local",
				},
			},
		},
		"example_requests": map[string]any{
			"health":         "curl -sf " + cfg.Endpoint + "/health",
			"chat":           fmt.Sprintf(`curl -s %s/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"%s","messages":[{"role":"user","content":"Hello"}],"stream":false}'`, cfg.Endpoint, cfg.ModelAlias),
			"chat_streaming": fmt.Sprintf(`curl -s %s/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"%s","messages":[{"role":"user","content":"Hello"}],"stream":true}'`, cfg.Endpoint, cfg.ModelAlias),
			"embed":          fmt.Sprintf(`curl -s %s/v1/embeddings -H "Content-Type: application/json" -d '{"model":"%s","input":"text to embed"}'`, cfg.Endpoint, cfg.ModelAlias),
			"models":         "curl -s " + cfg.Endpoint + "/v1/models",
			"metrics":        "curl -s " + cfg.Endpoint + "/metrics | head -20",
		},
		"management": map[string]any{
			"validate":          "ruby tests/llama_integration.rb --quick",
			"full_test":         "ruby tests/llama_integration.rb",
			"status":            "llama-ctl status",
			"config":            "llama-ctl config",
			"logs":              "llama-ctl logs",
			"restart":           "llama-ctl restart",
			"after_yaml_change": "llama-ctl install && llama-ctl restart",
		},
	}

	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	return enc.Encode(payload)
}

func renderMarkdown(w io.Writer, cfg Config, now time.Time) error {
	host, _ := os.Hostname()
	if host == "" {
		host = "localhost"
	}
	modelFile := cfg.ModelFile
	if modelFile == "" {
		modelFile = "unknown"
	}
	modelFileRule := cfg.ModelFile
	if modelFileRule == "" {
		modelFileRule = "..."
	}

	_, err := fmt.Fprintf(w, `# llama.cpp Local Inference — Capability Reference

> Generated: %s
> Machine: %s · %s
> Server: %s  · Status: **%s**

## Quick Facts

| Field | Value |
|---|---|
| Endpoint | `+"`%s`"+` |
| **Model name for API calls** | `+"`%s`"+` ← always use this |
| Model file on disk | `+"`%s`"+` ← never use this in API calls |
| Profile | `+"`%s`"+` |
| Context window | %d tokens |
| Parallel slots | %d |
| Max embedding tokens | %d (~%d words) |
| Auth | None required (any Bearer value works) |

---

## Supported Capabilities

### ✅ Chat completions
`+"```"+`
POST %s/v1/chat/completions
Content-Type: application/json

{"model":"%s","messages":[{"role":"user","content":"Hello"}],"stream":false}
`+"```"+`
- System role supported (use `+"`"+`{"role":"system","content":"..."}`+"`"+`)
- Streaming supported (`+"`\"stream\":true`"+` → Server-Sent Events)
- Tool/function calling supported (Qwen2.5 model with Jinja template)
- Multi-turn: include full message history in the `+"`messages`"+` array

### ✅ Embeddings
`+"```"+`
POST %s/v1/embeddings
Content-Type: application/json

{"model":"%s","input":"text to embed"}
{"model":"%s","input":["batch","of","strings"]}
`+"```"+`
- **Hard limit: %d tokens per request** (~%d words)
- Exceeding the limit returns HTTP 500: "input (N tokens) is too large to process"
- Batch input (array of strings) is supported

### ✅ Models list
`+"```"+`
GET %s/v1/models
`+"```"+`
Returns `+"`"+`{"data":[{"id":"%s","..."}]}`+"`"+` — the alias, not the filename.

### ✅ Health check
`+"```"+`
GET %s/health
→ {"status":"ok"}
`+"```"+`

### ✅ Prometheus metrics
`+"```"+`
GET %s/metrics
`+"```"+`

### ❌ Not supported
- `+"`POST /v1/images/generations`"+` — not implemented by llama-server
- Audio transcription — no Whisper model loaded
- Moderation endpoint — OpenAI-proprietary

---

## Critical Rules — Read Before Integrating

### 1. Model name = alias, never the filename
The server advertises itself as **`+"`%s`"+`** (set by `+"`server.alias`"+` in `+"`etc/ai-models.yaml`"+`).
Always use this alias in the `+"`model`"+` field of every API request.
The GGUF filename (`+"`%s`"+`) is only for disk/download operations.

### 2. Auth: anything goes
llama.cpp ignores the Authorization header. Set `+"`api_key`"+` to any non-empty string in your SDK.

### 3. Embedding token ceiling
Requests with more than **%d tokens** return HTTP 500.
This is controlled by `+"`server.ubatch_size`"+` in `+"`etc/ai-models.yaml`"+`.
After changing it, run `+"`llama-ctl install`"+` to regenerate the launchd plist.

### 4. Plist staleness
The running server reads its flags from a launchd plist generated at install time.
YAML changes are **not** live-reloaded. After any change to `+"`etc/ai-models.yaml`"+`:
`+"```bash"+`
llama-ctl install   # regenerates plist
llama-ctl restart   # applies it
`+"```"+`

---

## Framework Integration

### RubyLLM (ruby_llm gem)

`+"```ruby"+`
RubyLLM.configure do |c|
  c.openai_api_key          = "local"              # ignored by llama.cpp
  c.openai_api_base         = "%s/v1"
  c.openai_use_system_role  = true
  c.default_model           = "%s"
  c.default_embedding_model = "%s"
  c.request_timeout         = 90
  c.max_retries             = 0
end

# CRITICAL: every chat/embed call needs these two kwargs
# RubyLLM has an internal model registry; "local" is not in it.
# assume_model_exists: true bypasses the check.
chat = RubyLLM.chat(model: "%s", provider: "openai", assume_model_exists: true)
reply = chat.ask("Hello!")

# Embeddings
emb = RubyLLM.embed("some text", model: "%s", provider: "openai", assume_model_exists: true)
puts emb.vectors.length

# Streaming
chat.ask("Tell me a story") { |chunk| print chunk.content }

# Tool use
class MyTool < RubyLLM::Tool
  description "Does something useful"
  param :input, type: "string", desc: "The input", required: true
  def execute(input:) = { result: input.upcase }
end
chat.with_tool(MyTool.new)
`+"```"+`

### OpenAI Python SDK

`+"```python"+`
from openai import OpenAI

client = OpenAI(
    base_url="%s/v1",
    api_key="local",          # ignored
)

# Chat
response = client.chat.completions.create(
    model="%s",
    messages=[{"role": "user", "content": "Hello"}]
)
print(response.choices[0].message.content)

# Embeddings
emb = client.embeddings.create(
    model="%s",
    input="text to embed"
)
print(len(emb.data[0].embedding))
`+"```"+`

### OpenAI Node.js SDK

`+"```javascript"+`
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "%s/v1",
  apiKey: "local",            // ignored
});

// Chat
const response = await client.chat.completions.create({
  model: "%s",
  messages: [{ role: "user", content: "Hello" }],
});
console.log(response.choices[0].message.content);
`+"```"+`

### Raw curl

`+"```bash"+`
# Chat
curl -s %s/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"%s","messages":[{"role":"user","content":"Hi"}]}'

# Embed
curl -s %s/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"%s","input":"hello world"}'

# Streaming
curl -s %s/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"%s","messages":[{"role":"user","content":"Count to 5"}],"stream":true}'
`+"```"+`

---

## Debugging

`+"```bash"+`
llama-ctl status          # launchd state + health + active model
llama-ctl logs            # tail server log (startup errors, OOM, etc.)
llama-ctl config          # full resolved config (what the server actually started with)
llama-ctl health          # exits 0=up, 1=down

# Run the full integration test suite
ruby tests/llama_integration.rb           # all 14 tests
ruby tests/llama_integration.rb --quick   # 8 fast tests (used by zdots-ctl check)

# Debug raw RubyLLM HTTP traffic
RUBYLLM_DEBUG=true ruby your_script.rb
`+"```"+`

---

## Management

`+"```bash"+`
llama-ctl start           # start server
llama-ctl stop            # stop server
llama-ctl restart         # restart (does NOT reload yaml — run install first)
llama-ctl install         # regenerate plist from yaml + restart
llama-ctl model-download  # download active profile GGUF from HuggingFace
llama-ctl model-list      # show downloaded GGUFs with sizes
llama-ctl validate        # validate etc/ai-models.yaml syntax
`+"```"+`

Config source of truth: `+"`etc/ai-models.yaml`"+`
Integration tests: `+"`tests/llama_integration.rb`"+`
`,
		now.UTC().Format("2006-01-02 15:04 UTC"),
		host, runtime.GOARCH,
		cfg.Endpoint, cfg.Health,
		cfg.Endpoint,
		cfg.ModelAlias,
		modelFile,
		cfg.Profile,
		cfg.ContextWindow,
		cfg.ParallelSlots,
		cfg.MaxEmbedTokens, cfg.MaxEmbedWords,
		cfg.Endpoint, cfg.ModelAlias,
		cfg.Endpoint, cfg.ModelAlias, cfg.ModelAlias,
		cfg.MaxEmbedTokens, cfg.MaxEmbedWords,
		cfg.Endpoint, cfg.ModelAlias,
		cfg.Endpoint,
		cfg.Endpoint,
		cfg.ModelAlias, modelFileRule,
		cfg.MaxEmbedTokens,
		cfg.Endpoint, cfg.ModelAlias, cfg.ModelAlias, cfg.ModelAlias, cfg.ModelAlias,
		cfg.Endpoint, cfg.ModelAlias, cfg.ModelAlias,
		cfg.Endpoint, cfg.ModelAlias,
		cfg.Endpoint, cfg.ModelAlias, cfg.Endpoint, cfg.ModelAlias, cfg.Endpoint, cfg.ModelAlias,
	)
	return err
}

func renderText(w io.Writer, cfg Config, now time.Time) error {
	b := func(s string) string { return "\033[1m" + s + "\033[0m" }
	g := func(s string) string { return "\033[0;32m" + s + "\033[0m" }
	r := func(s string) string { return "\033[0;31m" + s + "\033[0m" }
	c := func(s string) string { return "\033[0;36m" + s + "\033[0m" }

	rule := strings.Repeat("─", 60)
	statusStr := r(cfg.Health)
	if cfg.Health == "ok" {
		statusStr = g("ok")
	}
	modelFile := cfg.ModelFile
	if modelFile == "" {
		modelFile = "(unknown)"
	}

	fmt.Fprintf(w, "\n%s\n%s\n\n", b("llama.cpp capability report"), now.Format("2006-01-02 15:04"))
	fmt.Fprintf(w, "%s\n", rule)
	fmt.Fprintf(w, "  %-22s %s\n", "endpoint:", cfg.Endpoint)
	fmt.Fprintf(w, "  %-22s %s\n", "status:", statusStr)
	fmt.Fprintf(w, "  %-22s %s\n", "model alias (use this):", c(cfg.ModelAlias))
	fmt.Fprintf(w, "  %-22s %s\n", "model file (disk only):", modelFile)
	fmt.Fprintf(w, "  %-22s %s\n", "profile:", cfg.Profile)
	fmt.Fprintf(w, "%s\n", rule)

	fmt.Fprintf(w, "\n%s\n", b("Capabilities"))
	capLine := func(ok bool, label, detail string) {
		if ok {
			fmt.Fprintf(w, "  %s  %-30s %s\n", g("✓"), label, c(detail))
		} else {
			fmt.Fprintf(w, "  %s  %-30s %s\n", r("✗"), label, detail)
		}
	}
	capLine(true, "Chat completions", "POST /v1/chat/completions")
	capLine(true, "Streaming (SSE)", "stream:true")
	capLine(true, "System role", "role:system supported")
	capLine(true, "Tool/function calling", "Qwen2.5 + jinja template")
	capLine(true, "Multi-turn conversation", "full history in messages[]")
	capLine(cfg.EmbeddingsEnabled, "Embeddings", fmt.Sprintf("POST /v1/embeddings  (max %d tokens)", cfg.MaxEmbedTokens))
	capLine(true, "Models list", "GET /v1/models")
	capLine(true, "Health check", "GET /health")
	capLine(cfg.MetricsEnabled, "Prometheus metrics", "GET /metrics")
	capLine(false, "Image generation", "not implemented by llama-server")
	capLine(false, "Audio transcription", "no Whisper model loaded")
	capLine(false, "Moderation", "OpenAI-proprietary endpoint")

	fmt.Fprintf(w, "\n%s\n", b("Constraints"))
	fmt.Fprintf(w, "  %-28s %d tokens\n", "context window:", cfg.ContextWindow)
	fmt.Fprintf(w, "  %-28s %d tokens (~%d words)\n", "max embed tokens:", cfg.MaxEmbedTokens, cfg.MaxEmbedWords)
	fmt.Fprintf(w, "  %-28s %d tokens (-1 = unlimited)\n", "max generation:", cfg.NPredict)
	fmt.Fprintf(w, "  %-28s %d\n", "parallel slots:", cfg.ParallelSlots)
	fmt.Fprintf(w, "  %-28s %s/%s\n", "KV cache:", cfg.CacheTypeK, cfg.CacheTypeV)
	fmt.Fprintf(w, "  %-28s none (any Bearer value accepted)\n", "auth:")

	fmt.Fprintf(w, "\n%s\n", b("Integration rules"))
	fmt.Fprintf(w, "  1. Model name: always use alias %s — never the GGUF filename\n", c(cfg.ModelAlias))
	fmt.Fprintf(w, "  2. RubyLLM: pass %s on every call\n", c(`assume_model_exists: true, provider: "openai"`))
	fmt.Fprintf(w, "  3. Embeddings: inputs > %d tokens → HTTP 500\n", cfg.MaxEmbedTokens)
	fmt.Fprintf(w, "  4. YAML changes: run %s to apply\n", c("llama-ctl install && llama-ctl restart"))

	fmt.Fprintf(w, "\n%s\n", b("Outputs"))
	fmt.Fprintf(w, "  llama-caps --json   machine-readable JSON capability document\n")
	fmt.Fprintf(w, "  llama-caps --md     Markdown — paste into any AI chat\n")

	fmt.Fprintf(w, "\n%s\n", b("Validation"))
	fmt.Fprintf(w, "  ruby tests/llama_integration.rb --quick   8 tests, fast\n")
	fmt.Fprintf(w, "  ruby tests/llama_integration.rb            14 tests, full\n\n")
	return nil
}
