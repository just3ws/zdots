package agentguide

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/ctlstatus"
)

func usage() string {
	return `Usage: agent-guide [--json]

Options:
  --json      Emit a JSON object with service status and connection info
  -h, --help  Show this help

With no options: human-readable guide with live service status.
With --json: machine-readable JSON suitable for jq filtering.
`
}

// Run executes the agent-guide command and returns the exit code.
func Run(args []string) int {
	jsonMode := false
	for _, arg := range args {
		switch arg {
		case "--json":
			jsonMode = true
		case "-h", "--help":
			fmt.Print(usage())
			return 0
		default:
			fmt.Fprintf(os.Stderr, "agent-guide: unknown option: %s\n", arg)
			fmt.Fprint(os.Stderr, usage())
			return 1
		}
	}

	home, _ := os.UserHomeDir()
	zdotdir := envOr("ZDOTDIR", filepath.Join(home, ".config", "zsh"))
	xdgState := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	logDir := envOr("ZDOTS_LOG_DIR", filepath.Join(xdgState, "zsh"))
	logAnalyzer := filepath.Join(zdotdir, "bin", "zdots-log-analyze")

	aiEndpoint := envOr("ZDOTS_AI_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_AI_HOST", "127.0.0.1"), envOr("ZDOTS_AI_PORT", "11500")))
	otelEndpoint := envOr("ZDOTS_OTLP_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_OTEL_HOST", "127.0.0.1"), envOr("ZDOTS_OTEL_HTTP_PORT", "4318")))
	o2URL := envOr("ZDOTS_O2_ENDPOINT", fmt.Sprintf("http://%s:%s", envOr("ZDOTS_O2_HOST", "127.0.0.1"), envOr("ZDOTS_O2_PORT", "5080")))
	statusURL := fmt.Sprintf("http://%s:%s", envOr("ZDOTS_STATUS_HOST", "127.0.0.1"), envOr("ZDOTS_STATUS_PORT", "11600"))

	platformVersion := readTrimmedOr(filepath.Join(zdotdir, "VERSION"), "unknown")

	var (
		myContract        = "my.structure.v1"
		myPlatformVersion = "unknown"
		aiUp              = false
		aiModelID         = "unknown"
		otelUp            = false
		o2Up              = false
		colimaUp          = false
		whisperUp         = false
		fabricUp          = false
		colimaSock        = ""
	)

	var wg sync.WaitGroup

	// 1. adots-my doctor --json (once)
	wg.Add(1)
	go func() {
		defer wg.Done()
		if _, err := exec.LookPath("adots-my"); err != nil {
			return
		}
		out := runCmd(3*time.Second, "adots-my", "doctor", "--json")
		var doc struct {
			ContractVersion string `json:"contract_version"`
			PlatformVersion string `json:"platform_version"`
		}
		if json.Unmarshal(out, &doc) == nil {
			if doc.ContractVersion != "" {
				myContract = doc.ContractVersion
			}
			if doc.PlatformVersion != "" {
				myPlatformVersion = doc.PlatformVersion
			}
		}
	}()

	// 2. in-process ctlstatus probe (replaces zdots-ctl status --json subprocess)
	wg.Add(1)
	go func() {
		defer wg.Done()
		st := ctlstatus.Probe(zdotdir)
		aiUp = st.AIServer || st.AISocketListening
		if st.AIModel != "" && st.AIModel != "unknown" {
			aiModelID = st.AIModel
		} else {
			aiModelID = envOr("ZDOTS_AI_MODEL", "local")
		}
		if st.AIEndpoint != "" {
			aiEndpoint = st.AIEndpoint
		}
		otelUp = st.OTelCollector
		if st.OTLPEndpoint != "" {
			otelEndpoint = st.OTLPEndpoint
		}
		o2Up = st.OpenObserve
		if st.O2URL != "" {
			o2URL = st.O2URL
		}
		colimaUp = st.Colima
		if colimaUp && !jsonMode {
			colimaSock = strings.TrimSpace(string(runCmd(2*time.Second, "colima-status", "socket")))
		}
	}()

	// 3. Tool presence checks
	wg.Add(1)
	go func() {
		defer wg.Done()
		if _, err := exec.LookPath("whisper-cpp"); err == nil {
			whisperUp = true
		}
		if _, err := exec.LookPath("fabric-ai"); err == nil {
			fabricUp = true
		}
	}()

	wg.Wait()

	currentUser := "unknown"
	if u, err := user.Current(); err == nil && u.Username != "" {
		currentUser = u.Username
	}
	aiMode := envOr("ZDOTS_AI_MODE", "local")
	cloudKeysSet := os.Getenv("OPENAI_API_KEY") != "" || os.Getenv("GEMINI_API_KEY") != ""

	if jsonMode {
		payload := guideJSON{
			Platform: platformBlock{
				Version:           platformVersion,
				Scheme:            "imperial-calver",
				MyContract:        myContract,
				MyVersion:         myPlatformVersion,
				VersionedSurfaces: []string{"zdots", "adots", "my", "vdots", "ztranscribe", "media-pipeline", "just3ws.github.io"},
			},
			Services: servicesBlock{
				LlamaCPP:    llamaService{Up: aiUp, Endpoint: aiEndpoint, Model: aiModelID, Start: "llama-ctl start"},
				WhisperCPP:  simpleService{Up: whisperUp, Start: "whisper-ctl install"},
				FabricAI:    simpleService{Up: fabricUp, Start: "brew install fabric-ai"},
				OTelCol:     endpointService{Up: otelUp, Endpoint: otelEndpoint, Start: "otel-collector start"},
				Colima:      simpleService{Up: colimaUp, Start: "colima start"},
				OpenObserve: o2Service{Up: o2Up, URL: o2URL, Start: "zsvc start o2"},
			},
			AI: aiBlock{
				Mode:             aiMode,
				InferenceCommand: "ai-query",
				Endpoint:         aiEndpoint,
				Model:            aiModelID,
				SubprocessSafe:   true,
				InteractiveOnly:  []string{"ai"},
				AiderCommand:     "zaider",
				KnowledgeBase:    "zdots-ctx query / zdots-ctx hydrate",
				DeployLogs:       "zdots-log-analyze update|bootstrap|upgrade [--ai]",
				ExpertPatterns:   "zdots-ask --pattern <name> / zdots-pattern",
				CloudKeysSet:     cloudKeysSet,
			},
			OTel: otelBlock{
				OTLPHTTPEndpoint: otelEndpoint,
				OTLPGRPCEndpoint: "grpc://127.0.0.1:4317",
				Protocol:         "http/protobuf",
				Backend:          "openobserve",
				UIURL:            o2URL,
			},
			Env: envBlock{
				ZDOTSDatabaseURL:         "postgresql://zdots_rw@/my",
				ZDOTSAIEndpoint:          aiEndpoint,
				ZDOTSAIModel:             "local",
				OTELExporterOTLPEndpoint: otelEndpoint,
				OTELExporterOTLPProtocol: "http/protobuf",
			},
			AICaps: aiCapsBlock{
				Text:     "llama-caps",
				JSON:     "llama-caps --json",
				Markdown: "llama-caps --md",
				Note:     "Full capability + integration guide for the local llama.cpp server",
			},
			MCP: mcpBlock{
				Servers: []mcpServer{
					{
						Name:  "llama-mcp",
						Tools: []string{"llama_capabilities", "llama_health", "llama_config", "llama_run_test", "llama_integration_snippet"},
						Note:  "Inference control plane",
					},
					{
						Name:  "ctx-mcp",
						Tools: []string{"ctx_status", "ctx_query", "ctx_hydrate", "ctx_add_methodology", "ctx_add_lesson", "ctx_capture", "ctx_enqueue", "ctx_jobs"},
						Note:  "Knowledge Layer — second brain (lessons, methodologies, session residue)",
					},
					{
						Name:  "o2-mcp",
						Tools: []string{"o2_logs", "o2_errors", "o2_failures", "o2_slow", "o2_service", "o2_trace"},
						Note:  "Read-only OpenObserve queries — logs/metrics/traces",
					},
					{
						Name:  "backlog",
						Tools: []string{"task_list", "task_view", "task_create", "task_edit", "milestone_list", "document_search"},
						Note:  "Backlog.md task tracker — see also https://zdots.localhost/backlog for a read-only view",
					},
				},
				Note: "Available to compatible MCP clients when registered in their client configuration",
			},
			Discovery: discoveryBlock{
				Man:                statusURL + "/man (or: man <cmd> locally)",
				Docs:               statusURL + "/docs (or: docs/*.md)",
				Help:               statusURL + "/help (or: zdots help <cmd>)",
				Backlog:            statusURL + "/backlog (read-only board)",
				Theme:              statusURL + "/theme/palette.json (Kanagawa Wave)",
				Services:           "zsvc map --json (purpose/auth/example per service)",
				Vocabulary:         "zdots-ctx concept <slug> | concept resolve <word>",
				ExternalAgentsNote: "Tenant/corporate AI sessions on this machine: reads above are free (loopback-trusted, no PHI). Route requests/questions through ${ZDOTS_WORK_EXT:-~/.config/zdots-work}/handoffs/.",
			},
			Database: databaseBlock{
				Name:          "my",
				AppUser:       "zdots_rw",
				AppURL:        "postgresql://zdots_rw@/my",
				ReadonlyUser:  "zdots_ro",
				ReadonlyURL:   "postgresql://zdots_ro@/my",
				MigrationUser: currentUser + " (OS superuser via ZDOTS_MIGRATION_URL)",
				Note:          "All writes go through zdots-ctx or context-engine only. Use zdots_ro for safe psql exploration.",
				Explore:       "psql -U zdots_ro my",
			},
			Docs: docsBlock{
				PlatformControl: "zdots-ctl check / up / down / reset / status",
				ServiceControl:  "zsvc list / health --json / logs all --json / diag <service>",
				Lifecycle:       "docs/lifecycle.md",
				AI:              "docs/llama-cpp.md",
				DeployLogs:      "docs/deploy-log-analysis.md",
				OTel:            "docs/otel-collector-guide.md",
				Agents:          "AGENTS.md",
			},
			Diagnostics: diagnosticsBlock{
				LogDir:            logDir,
				LogAnalyzer:       logAnalyzer,
				ServiceHealthJSON: "zsvc health --json",
				ServiceLogsJSON:   "zsvc logs all --json",
				ServiceLogsTail:   "zsvc logs all",
				LocalURLsHealth:   "zsvc health --json | jq .local_urls",
				Update:            "zdots-log-analyze update",
				Bootstrap:         "zdots-log-analyze bootstrap",
				Upgrade:           "zdots-log-analyze upgrade",
				AI:                "zdots-log-analyze update --ai",
			},
		}
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(payload)
		return 0
	}

	printHuman(platformVersion, myPlatformVersion, myContract, logDir, aiUp, aiModelID, aiEndpoint, otelUp, otelEndpoint, colimaUp, colimaSock, o2Up, o2URL, fabricUp)
	return 0
}

type guideJSON struct {
	Platform    platformBlock    `json:"platform"`
	Services    servicesBlock    `json:"services"`
	AI          aiBlock          `json:"ai"`
	OTel        otelBlock        `json:"otel"`
	Env         envBlock         `json:"env"`
	AICaps      aiCapsBlock      `json:"ai_caps"`
	MCP         mcpBlock         `json:"mcp"`
	Discovery   discoveryBlock   `json:"discovery"`
	Database    databaseBlock    `json:"database"`
	Docs        docsBlock        `json:"docs"`
	Diagnostics diagnosticsBlock `json:"diagnostics"`
}

type platformBlock struct {
	Version           string   `json:"version"`
	Scheme            string   `json:"scheme"`
	MyContract        string   `json:"my_contract"`
	MyVersion         string   `json:"my_version"`
	VersionedSurfaces []string `json:"versioned_surfaces"`
}

type servicesBlock struct {
	LlamaCPP    llamaService    `json:"llama_cpp"`
	WhisperCPP  simpleService   `json:"whisper_cpp"`
	FabricAI    simpleService   `json:"fabric_ai"`
	OTelCol     endpointService `json:"otelcol"`
	Colima      simpleService   `json:"colima"`
	OpenObserve o2Service       `json:"openobserve"`
}

type llamaService struct {
	Up       bool   `json:"up"`
	Endpoint string `json:"endpoint"`
	Model    string `json:"model"`
	Start    string `json:"start"`
}

type simpleService struct {
	Up    bool   `json:"up"`
	Start string `json:"start"`
}

type endpointService struct {
	Up       bool   `json:"up"`
	Endpoint string `json:"endpoint"`
	Start    string `json:"start"`
}

type o2Service struct {
	Up    bool   `json:"up"`
	URL   string `json:"url"`
	Start string `json:"start"`
}

type aiBlock struct {
	Mode             string   `json:"mode"`
	InferenceCommand string   `json:"inference_command"`
	Endpoint         string   `json:"endpoint"`
	Model            string   `json:"model"`
	SubprocessSafe   bool     `json:"subprocess_safe"`
	InteractiveOnly  []string `json:"interactive_only"`
	AiderCommand     string   `json:"aider_command"`
	KnowledgeBase    string   `json:"knowledge_base"`
	DeployLogs       string   `json:"deploy_logs"`
	ExpertPatterns   string   `json:"expert_patterns"`
	CloudKeysSet     bool     `json:"cloud_keys_set"`
}

type otelBlock struct {
	OTLPHTTPEndpoint string `json:"otlp_http_endpoint"`
	OTLPGRPCEndpoint string `json:"otlp_grpc_endpoint"`
	Protocol         string `json:"protocol"`
	Backend          string `json:"backend"`
	UIURL            string `json:"ui_url"`
}

type envBlock struct {
	ZDOTSDatabaseURL         string `json:"ZDOTS_DATABASE_URL"`
	ZDOTSAIEndpoint          string `json:"ZDOTS_AI_ENDPOINT"`
	ZDOTSAIModel             string `json:"ZDOTS_AI_MODEL"`
	OTELExporterOTLPEndpoint string `json:"OTEL_EXPORTER_OTLP_ENDPOINT"`
	OTELExporterOTLPProtocol string `json:"OTEL_EXPORTER_OTLP_PROTOCOL"`
}

type aiCapsBlock struct {
	Text     string `json:"text"`
	JSON     string `json:"json"`
	Markdown string `json:"markdown"`
	Note     string `json:"note"`
}

type mcpBlock struct {
	Servers []mcpServer `json:"servers"`
	Note    string      `json:"note"`
}

type mcpServer struct {
	Name  string   `json:"name"`
	Tools []string `json:"tools"`
	Note  string   `json:"note"`
}

type discoveryBlock struct {
	Man                string `json:"man"`
	Docs               string `json:"docs"`
	Help               string `json:"help"`
	Backlog            string `json:"backlog"`
	Theme              string `json:"theme"`
	Services           string `json:"services"`
	Vocabulary         string `json:"vocabulary"`
	ExternalAgentsNote string `json:"external_agents_note"`
}

type databaseBlock struct {
	Name          string `json:"name"`
	AppUser       string `json:"app_user"`
	AppURL        string `json:"app_url"`
	ReadonlyUser  string `json:"readonly_user"`
	ReadonlyURL   string `json:"readonly_url"`
	MigrationUser string `json:"migration_user"`
	Note          string `json:"note"`
	Explore       string `json:"explore"`
}

type docsBlock struct {
	PlatformControl string `json:"platform_control"`
	ServiceControl  string `json:"service_control"`
	Lifecycle       string `json:"lifecycle"`
	AI              string `json:"ai"`
	DeployLogs      string `json:"deploy_logs"`
	OTel            string `json:"otel"`
	Agents          string `json:"agents"`
}

type diagnosticsBlock struct {
	LogDir            string `json:"log_dir"`
	LogAnalyzer       string `json:"log_analyzer"`
	ServiceHealthJSON string `json:"service_health_json"`
	ServiceLogsJSON   string `json:"service_logs_json"`
	ServiceLogsTail   string `json:"service_logs_tail"`
	LocalURLsHealth   string `json:"local_urls_health"`
	Update            string `json:"update"`
	Bootstrap         string `json:"bootstrap"`
	Upgrade           string `json:"upgrade"`
	AI                string `json:"ai"`
}

func bold(s string) string { return "\033[1m" + s + "\033[0m" }
func ok(s string) string   { return "\033[0;32m[UP]  \033[0m " + s }
func down(s string) string { return "\033[0;31m[DOWN]\033[0m " + s }
func head(s string) {
	fmt.Printf("\n%s\n%s\n", bold(s), strings.Repeat("-", len(s)))
}

func printHuman(
	platformVersion, myPlatformVersion, myContract, logDir string,
	aiUp bool, aiModelID, aiEndpoint string,
	otelUp bool, otelEndpoint string,
	colimaUp bool, colimaSock string,
	o2Up bool, o2URL string,
	fabricUp bool,
) {
	fmt.Print(bold("=== Zdots Agent Guide ==="))
	fmt.Printf("\nPlatform: %s  (six-surface epoch · my=%s / %s)\n", platformVersion, myPlatformVersion, myContract)
	fmt.Println("This machine is the central hub for AI inference and OTel observability.")
	fmt.Println("For machine-readable output: agent-guide --json")

	head("Platform Control — zdots-ctl")
	fmt.Print(`zdots-ctl is the single command to manage the full Zdots platform.

  zdots-ctl check        deep diagnostic: tools, configs, health, OTel, disk
  zdots-ctl status       live aggregate status of all services
  zdots-ctl up           start all services in dependency order (idempotent)
  zdots-ctl down         stop all services cleanly
  zdots-ctl reset        full platform restart (down + up)
  zdots-ctl install      first-time setup on a new workstation
  zdots-ctl status --json  machine-readable JSON
`)

	head("Core Guides")
	fmt.Print(`Refer to these for architectural and workflow standards:

  docs/lifecycle.md         Project lifecycle, setup, and tutorial
  AGENTS.md                 Agent mandates, RTK optimization, PHI rules
  CONTEXT.md                Domain language and active project state
  docs/tooling.md           Full CLI reference table
  backlog/docs/doc-003      Roadmap + vision (learns faster than it decays)
  backlog/docs/doc-004      North star, alignment levers, KPIs, OKRs

Command discovery, always available:
  zdots help                list every platform command with one-liners
  zdots help <cmd>          man page -> --help -> catalog, first hit wins
  man <cmd>                 every bin/ command has a man page (contract-tested)

Vocabulary — canonical terms (Seam, Platform Service, Actor, ...), not prose:
  zdots-ctx concept <slug>              look up a term
  zdots-ctx concept resolve <word>      resolve an alias -> canonical term

Same content, browsable over HTTP (zdots.localhost, loopback-trusted, no auth) —
useful for any local agent that would rather GET than shell out:
  https://zdots.localhost/man       every man page, cross-linked
  https://zdots.localhost/docs      every tracked *.md doc
  https://zdots.localhost/help      every command's --help
  https://zdots.localhost/backlog   read-only Backlog.md board
  https://zdots.localhost/theme     platform theme (Kanagawa Wave) + palette.json

The read-only cross-project System Atlas is separately exposed on the trusted
LAN at https://lan.just3ws.com (only /map and /map.json; no docs/logs/backlog):
  https://lan.just3ws.com/           homepage redirect to /map
  https://lan.just3ws.com/map.json   coarse service state, timestamped
Select map nodes for hostname-family ownership, active vs candidate LAN names,
nginx path-to-upstream routing, internal ports, and service interconnections.
`)

	head("Service Control — zsvc")
	fmt.Print(`Use zsvc for per-service diagnostics and consolidated logs.

  zsvc list                 service registry with state, pid, endpoint
  zsvc health               service liveness + nginx-fronted .local URLs
  zsvc health --json        machine-readable health for AI tools
  zsvc logs all --paths     print every registered log source
  zsvc logs all --json      machine-readable log source inventory
  zsvc logs all             tail all registered logs from one terminal
  zsvc diag <service>       status + health + launchd state + recent logs
  zsvc map [--json] [svc]   "you are here": purpose, API kind, auth, a
                            runnable example, and dependencies per service —
                            for any tool/agent deciding what to call and how

Registered services (11 managed): llama, embed, otel, o2, colima, nginx,
postgres, redis, worker, status (zdots-statusd), gemstash.

Log rotation (when a service log grows large):
  log-rotate <service>          compress + truncate in-place (safe with open FDs)
  log-rotate <service> --dry-run  preview size and path without rotating
  Archives land next to the log: <log>.YYYYMMDD-HHMMSS.gz
`)

	head("Deploy Logs — Non-OTel Diagnostics")
	fmt.Printf(`Phase-marked transcripts:
  %s/bootstrap-*.log
  %s/zdots-update-local-*.log
  %s/upgrade-homebrew-*.log

AI/HI handoff:
  zdots-log-analyze update
  zdots-log-analyze bootstrap --tail 400
  zdots-log-analyze upgrade --ai
  zdots-ctx diagnose-log update --tail 160

Live runtime insight (when OpenObserve is up; read-only, local, scrubbed):
  zdots-o2-query errors --since 1h     recent ERROR/FATAL logs
  zdots-o2-query failures              error-status spans
  zdots-o2-query trace <id>            all spans + logs for one trace

Workstation health:
  zdots-doctor               full check (env, services, observability, PHI posture)
  zdots-doctor --no-runtime  fast mode (own sections only)

These packs include a non-OTel system snapshot, so diagnostics still work when
the collector or OpenObserve are down.
`, logDir, logDir, logDir)

	head("Live Service Status")
	if aiUp {
		fmt.Printf("%s  model=%s  endpoint=%s\n", ok("llama.cpp (AI inference)"), aiModelID, aiEndpoint)
	} else {
		fmt.Printf("%s  endpoint=%s\n", down("llama.cpp (AI inference)"), aiEndpoint)
	}
	if otelUp {
		fmt.Printf("%s  http=%s  grpc=grpc://127.0.0.1:4317\n", ok("otelcol-contrib (OTel collector)"), otelEndpoint)
	} else {
		fmt.Printf("%s\n", down("otelcol-contrib (OTel collector)"))
	}
	if colimaUp {
		if colimaSock == "" {
			colimaSock = "(run colima-status socket)"
		}
		fmt.Printf("%s  socket=%s\n", ok("Colima (container runtime)"), colimaSock)
	} else {
		fmt.Printf("%s\n", down("Colima (container runtime)"))
	}
	if o2Up {
		fmt.Printf("%s  %s\n", ok("OpenObserve (logs/metrics/traces)"), o2URL)
	} else {
		fmt.Printf("%s\n", down("OpenObserve (logs/metrics/traces)"))
	}
	if !aiUp || !otelUp || !o2Up {
		fmt.Println("\n  To bring everything up: zdots-ctl up")
	}

	head("AI Inference — llama.cpp")
	fmt.Printf(`Endpoint:  %s
Model ID:  %s  (always use "local" as the model name in API calls)

CAPABILITY DISCOVERY — start here when integrating or debugging:
  llama-caps              full capability report (terminal)
  llama-caps --json       machine-readable capability + integration doc
  llama-caps --md         markdown — copy/paste to any AI (Gemini, ChatGPT, etc.)
  llama-caps --md | pbcopy

  MCP tools (register these servers in the MCP client you use):
    llama_capabilities    complete capability + integration guide
    llama_health          live health check
    llama_config          resolved server config with capacity limits
    llama_run_test        run integration test suite (quick or full)
    llama_integration_snippet  working code for ruby_llm / python / node / curl

  Knowledge Layer MCP tools (ctx-mcp):
    ctx_status            check intelligence suite connectivity
    ctx_query             search methodologies and lessons
    ctx_hydrate           get context for AI tasks
    ctx_add_methodology   record a new preferred methodology
    ctx_add_lesson        record a new lesson learnt
    ctx_capture           distill session residue
    ctx_enqueue           enqueue a background side-effect job
    ctx_jobs              list pending and running jobs

  llama-ctl config --json includes _discovery block with all bootstrap pointers

SUBPROCESS / AGENT USE — preferred method:
  ai-query "What does SIGPIPE mean?"
  git diff | ai-query "Write a commit message"
  cat error.log | ai-query "Find the root cause"
  ai-query --system "You are a JSON formatter" "pretty print this" < data.json

  Options: -s/--system TEXT   override system prompt
           -m/--model  NAME   override model name  (default: local)
           -e/--endpoint URL  override server URL

DIRECT HTTP — works from any context, no tooling required:
  curl -sf -m 2 %s/health
  curl -s %s/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"local","messages":[{"role":"user","content":"Hello"}],"stream":false}'
  curl -s %s/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"model":"local","input":"text to embed"}'
  curl -s %s/metrics

DO NOT USE from scripts/agents — interactive zsh only:
  ai "prompt"          # requires interactive zsh session

SERVICE MANAGEMENT:
  llama-ctl status          check launchd state + health + active model
  llama-ctl status --json   same, as JSON
  llama-ctl start           start server
  llama-ctl stop            stop server
  llama-ctl restart         restart server
  llama-ctl health          exits 0=up, 1=down
  llama-ctl health --json   same, as JSON
  llama-ctl logs            tail server log
  llama-ctl install         install + register launchd plist (first-time setup)
  llama-ctl model-download  download active profile GGUF from HuggingFace
  llama-ctl model-download --all  fetch every profile's model (recovery verb;
                            present files verified + skipped)
  llama-ctl validate        validate etc/ai-models.yaml

HARDWARE LIMITS (M4 MBA, 16GB RAM, 256GB disk):
  One active GGUF at a time. If OOM, switch to constrained profile:
    ZDOTS_AI_PROFILE=constrained llama-ctl install
  Full config: etc/ai-models.yaml
  Full guide:  docs/llama-cpp.md
`, aiEndpoint, aiModelID, aiEndpoint, aiEndpoint, aiEndpoint, aiEndpoint)

	head("Expert Patterns — fabric-ai")
	if fabricUp {
		fmt.Printf("%s\n", ok("fabric-ai (pattern library)"))
	} else {
		fmt.Printf("%s\n", down("fabric-ai (pattern library)"))
	}
	fmt.Print(`Usage:
  zdots-pattern               # Interactive selection via fzf
  zdots-pattern --context     # Prepend real-time zdots context to pattern
  zdots-ask --pattern <name>  # One-shot usage of a specific pattern

Patterns are stored in: ~/.config/fabric/patterns
Update with: fabric-ai --updatepatterns
`)

	head("Transcription — whisper.cpp")
	fmt.Print(`High-performance local audio-to-text.

MANAGEMENT:
  whisper-ctl install         install binary via Homebrew
  whisper-ctl model-download  download active profile's model (e.g. large-v3-turbo)
  whisper-ctl model-list      list downloaded models

USAGE:
  whisper-ctl transcribe <file>    transcribe audio to text
  recipes/transcribe <file>        transcribe + AI summary (with action items)

Models are stored in: ${XDG_DATA_HOME:-~/.local/share}/whisper-cpp/models
`)

	head("Job Queue — zdots-ctx")
	fmt.Print(`Postgres-backed async job queue. A launchd worker (com.zdots.worker) polls
every 5s and processes any registered type; you rarely need to run a worker
by hand.

ENQUEUE / INSPECT:
  zdots-ctx enqueue [--force] <type> <payload_json> [priority]
  zdots-ctx jobs                  list pending + recent jobs
  zdots-ctx result <job_id>       fetch a job's structured result (JSON)
  zdots-ctx requeue <job_id>      reset a failed/dead job to pending
  zdots-ctx cancel <job_id>       stop retrying (marks dead)
  zdots-ctx triage                review permanently-failed 'dead' jobs

Idempotent by construction: fingerprint = md5(type + payload_json), so
re-enqueuing the same call is a no-op unless --force.

REGISTERED JOB TYPES:
  transcription   {"url": "..."}                  yt-dlp + whisper, no result fetch
  transform       {"text": "...", "profile": "p"}  generic AI transform, tenant-fetchable
                  result via ` + "`zdots-ctx result`" + ` — see etc/prompts/jobs/transform/
  distill         {"url": "..."}                  YouTube → internal Lesson (not tenant-fetchable)
  ingest_media    internal (fan-out for long-audio transcription, Z-169)
  embed           internal (lesson/methodology embeddings)
  docs_sync       internal (living-docs regeneration)

` + "`transform`" + ` is the tenant-consumer contract (Z-199): external repos enqueue
text + a profile name, then fetch ` + "`{status, result: {output}}`" + ` by job ID
instead of hand-rolling direct-LLM calls. Add a profile by dropping a prompt
at etc/prompts/jobs/transform/<name>.txt — no code change needed.
`)

	head("Observability — OTel + OpenObserve")
	fmt.Printf(`Architecture:
  Your app → OTLP (http/protobuf :4318 or gRPC :4317)
           → otelcol-contrib (host, native)
           → OpenObserve (native binary, :5080)
           → UI / logs / metrics / traces at %s

CONNECT YOUR APP — set these env vars:
  export OTEL_EXPORTER_OTLP_ENDPOINT="%s"
  export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"

OPENOBSERVE:  %s  (login: root@zdots.local, password in Keychain)
  - Traces → OpenObserve
  - Logs   → OpenObserve
  - Metrics → OpenObserve (includes RED metrics auto-derived from traces)

VERIFY CONNECTIVITY:
  curl -sf %s/v1/traces \
    -H "Content-Type: application/json" \
    -d '{"resourceSpans":[]}'

COLLECTOR MANAGEMENT:
  otel-collector status           check if collector is running
  otel-collector status --json    same, as JSON
  otel-collector start            start host collector
  otel-collector stop             stop host collector
  otel-collector restart          restart (picks up config changes)
  otel-collector health           exits 0=up, 1=down
  otel-collector health --json    same, as JSON
  otel-collector validate         validate etc/otel-collector.yaml
  otel-collector logs             tail collector log
  otel-collector install          first-time: install otelcol-contrib binary

OBSERVABILITY MANAGEMENT (OpenObserve, native):
  zsvc start o2                   start OpenObserve
  zsvc stop o2                    stop it
  zsvc status o2                  state + health
  zsvc logs o2                    tail the log
  openobserve-ctl reinit          wipe + recreate root from Keychain
  otel-smoke --verify             emit a test batch and confirm it landed

Full guide: docs/openobserve.md
`, o2URL, otelEndpoint, o2URL, otelEndpoint)

	head("Filesystem Doctrine — The Idiot Test")
	fmt.Print(`This machine survived a near-total home-directory wipe on 2026-05-25 when an
AI agent ran ` + "`rm -rf ~/`" + ` after confusing a literal subdirectory named ` + "`~`" + `
with shell HOME expansion. The user killed the process mid-traversal; only a
permissions bottleneck in Music/ and go/pkg/mod/ saved Documents, Desktop,
and the GitHub repos. Permanent losses included shell config, history, the
entire ~/.config/ tree, and ~/context/work/ (irrecoverable research).

Read this before any operation that removes, moves, resets, cleans, wipes,
prunes, truncates, or overwrites filesystem state.

THE RULE
  Before any destructive command, apply the Idiot Test:
    "Would an idiot do this?"
  If yes — do not do it. Stop. Surface the resolved target list to the user
  and wait for explicit confirmation. The cost of pausing is zero. The cost
  of being wrong is unrecoverable.

WHAT COUNTS AS "AN IDIOT WOULD DO THIS"
  - rm -rf on any path that expands to or contains $HOME, ~, /, ., or *
  - Recursive deletes where the path comes from an unresolved variable
  - Any command whose target you have not echoed back and read
  - "Cleaning up" a directory you did not create in this session
  - Wildcards (*) at the top level of a deletion target
  - Force flags (-f, --force, --no-preserve-root) without explicit user ask
  - Touching dot-directories under $HOME you did not just write
  - Trusting that "~" in a script is HOME — it may be a literal directory

GUARDRAILS IN PLACE (backstop, not primary defense)
  conf.d/15-safe-rm.zsh wraps ` + "`rm`" + ` and hard-blocks:
    ~, $HOME, $HOME/, /, /usr, /etc, /bin, /sbin, /opt, /System,
    /Library, /Applications, and bare wildcard deletes of home contents.
  ` + "`del`" + ` is aliased to ` + "`trash`" + ` (macOS Trash) — prefer it over ` + "`rm`" + `.
  These guardrails fire only in interactive zsh. Subshells, bash scripts,
  IDE-spawned shells, and direct execve calls bypass them entirely.
  Do not rely on them. They are the last line, not the first.

PRIMARY DEFENSE — THINK FIRST
  1. Resolve every path variable to an absolute string before the command runs.
  2. Echo the resolved targets. Read them. Out loud, in your head, in the log.
  3. Ask: is any target a HOME, root, system, or shared path? If yes — stop.
  4. Ask the Idiot Test. If yes — stop.
  5. Prefer reversible operations: ` + "`trash`" + `/` + "`del`" + `, ` + "`mv`" + ` to a quarantine dir,
     or ` + "`git rm`" + ` inside a tracked repo. ` + "`rm -rf`" + ` is the last resort.
  6. When the user asks for cleanup, propose the target list first. Wait.

WHY THIS MATTERS HERE
  No Time Machine destination is configured on this machine. No APFS
  snapshots are retained. There is no cloud sync of $HOME. A destructive
  command that escapes the guardrails has no undo. The work lost in the
  2026-05-25 incident — including weeks of Work company research — is
  gone permanently. Do not add to that list.
`)

	head("Container Runtime — Colima + Docker")
	fmt.Print(`STOP. Do not call ` + "`colima status`" + ` directly or search for the docker socket path.
Use colima-status — it is the authoritative interface. ~/.colima is canonical
(colima ignores $XDG_CONFIG_HOME whenever it exists); hardcoded XDG paths
silently miss the socket.

STATUS AND HEALTH — always start here:
  colima-status              human-readable status
  colima-status --json       machine-readable JSON (use this in scripts/agents)
  colima-status health       exit 0 = healthy; exit 1 = down/missing socket
  colima-status socket       print the live socket path; exit 1 if missing

DOCKER_HOST — set it once from the authoritative source:
  export DOCKER_HOST="unix://$(colima-status socket)"
  # or inline:
  DOCKER_HOST=$(colima-status socket) docker ps

LOGS:
  colima-status logs         tail the colima autostart log

LIFECYCLE — use zsvc, not colima directly:
  zsvc start colima
  zsvc stop colima
  zsvc status colima

DISK RECLAIM (read dry-run first):
  docker-reclaim             dry run — shows what would be freed
  docker-reclaim -f          DESTRUCTIVE: prunes + fstrim

COLIMA STATUS JSON FIELDS (for scripts/agents):
  .healthy         true/false  — running AND socket present
  .socket          string      — canonical socket path
  .socket_exists   true/false  — socket file is live
  .docker_host     string      — ready-to-use DOCKER_HOST value
  .docker_reachable true/false — docker info succeeded
  .runtime         string      — "docker" or "containerd"
  .arch            string      — "aarch64" (Apple Silicon)
  .vm_type         string      — "macOS Virtualization.Framework"

~/.colima is canonical and permanent (Z-195/Z-181, decided 2026-07-04) — colima
itself ignores $XDG_CONFIG_HOME whenever ~/.colima exists, so zdots stopped
fighting it. colima-status/colima-autostart no longer probe or migrate to
$XDG_CONFIG_HOME/colima; if you see that path, something outside zdots created it.
`)

	head("Health Detectors & Usage Intelligence")
	fmt.Print(`Two standing detectors notify ONLY on worsening; ambient state lives in the
menu bar. Agents: READ their state, do not re-run the heavy cycles casually.

  zdots-watch status        doctor + nightly-suite state, evidence paths
  zdots-watch run           one doctor cycle (daily LaunchAgent's job)
  zdots-watch run-check     full bin/check cycle (~5 min; nightly 03:17 job)
  Evidence: last 7 full run outputs per detector under
  ~/.local/state/zsh/zdots-watch-runs/ — read these before re-diagnosing.

  zdots-usage               CLI usage intelligence from the trace stream
  zdots-usage errors        real failure rates (130 prompt-aborts separated)
  zdots-usage candidates    alias candidates + dead tools
  Caveat: raw session counts mix agent shells with human ones — sessions
  report segments by tty; trust the segmented numbers only.

  zdots-swiftbar            menu-bar pulse emitter (SwiftBar shim in ~/.swiftbar)

  make check                two-lane bats (~4:40; ZDOTS_CHECK_JOBS=1 for serial)
  make docs-contract        docs/help/man contract only (fast)

The operating adage (doc-004): if you do something exactly the same twice,
automate it — as a self-describing tool that names its check, its finding,
why it matters, and the exact fix line (see zdots-doctor's _fix pattern).
`)

	head("Operator Chat — Conventions for Cloud Agents")
	fmt.Print(`For Codex / Gemini / local agent sessions talking to the operator here:

  PUSHES ARE THE OPERATOR'S. Agent sessions must not push. Hand the exact
  command and ask the operator to run it in chat with a leading "!":
    ! git -C ~/.config/zsh push -u origin work
  One command per prompt (multi-line pastes arrive as chat text, not
  commands). The "!" output lands in the conversation for verification.

  COMMIT LOCALLY AND OFTEN — committing is not pushing. Stage exact paths,
  never add -A. bin/secret-scan before every commit.

  ZDOTS IS NOT YOURS TO FIX (AGENTS.md section 5) — infrastructure surprises
  become ` + "`zdots-issue \"...\"`" + `, not patches. The operator coordinates maintenance.

  LOCAL AI FIRST for anything PHI-adjacent: ai-query / zdots-ask keep
  inference on-box. Never paste secrets, keys, or PHI into a cloud session;
  the deny-list and guard are the backstop, not the policy.

  NAME YOUR LEVER (doc-004): every task states whether it serves DETECT,
  LEARN, COMPOUND, or OPERATE. Work that serves none gets questioned.

  BEFORE CLAIMING MISSING CONTEXT: zdots-ctx query / hydrate, zdots help,
  man <cmd>, and the newest ~/.config/adots/handoffs/ file — in that order.
`)

	head("External / Tenant Agents — Discovery Without a Boundary Crossing")
	fmt.Print(`Charter: zdots is the GENERIC platform/control-plane — enabling services,
"how to do things best on this workstation," capabilities any local app can
use. Tenant/corporate-specific work (business logic, org data, customer
content) belongs in that tenant's own app, never here. Inspiration flows
both ways at the pattern level (a UI approach, a discovery-endpoint shape)
without either side absorbing the other's domain-specific capabilities.

For an AI session running OUTSIDE this platform (a tenant/corporate app on
the same machine, e.g. a dashboard at some-other.localhost) that wants to
learn zdots' capabilities, adapt to changes, or borrow the theme:

  READS are free — same trust level as a public style guide, no creds, no PHI:
    https://zdots.localhost/{man,docs,help,backlog,theme}   browse directly
    zsvc map --json          purpose/auth/example per service
    capabilities --json      environment contract, live
    agent-guide --json       this guide, machine-readable
    zdots-ctx concept <slug> | concept resolve <word>       canonical vocabulary

  REQUESTS / QUESTIONS go through a relay, never straight into zdots' own
  state — the Message Bus (zdots-ctx bus-*) and zdots-issue are backed by
  personal platform infra (the ` + "`my`" + ` Postgres DB / backlog tracker); an
  external app writing there directly is the same boundary problem the
  work-extension layer (Z-262) exists to prevent:
    ${ZDOTS_WORK_EXT:-~/.config/zdots-work}/handoffs/YYYY-MM-DD.md
    Same intent/result/summary shape as the adots handoff files. A zdots-side
    agent or the operator triages these into a real zdots-issue if warranted.
`)

	head("Destructive Commands — Confirm Before Running")
	fmt.Print(`These commands permanently destroy data. Never run the destructive forms
without first reviewing a dry run or getting explicit user confirmation.

  docker-reclaim            DRY RUN — shows what would be freed (safe)
  docker-reclaim -f         DESTRUCTIVE: prunes all containers, images,
                            volumes, build cache, then runs fstrim in Colima VM.

  llama-ctl model-prune     DESTRUCTIVE: permanently deletes all GGUFs except
                            the currently active profile's model file.
                            Downloads are ~4.7GB and take time to restore.

  llama-ctl model-df        safe: shows model directory disk usage (read-only)
  docker-df                 safe: shows Docker disk usage (read-only)
`)

	head("Database Access")
	fmt.Print(`Database: my (PostgreSQL)

WRITE PATH — all mutations must go through intentional interfaces:
  zdots-ctx <command>          CLI interface (zdots_rw user)

READ-ONLY EXPLORATION — safe for ad-hoc queries:
  psql -U zdots_ro my          connects as zdots_ro (SELECT only)
  zdots-ctx query <term>       full-text search via the safe interface
  zdots-ctx status             connection check + record counts

DO NOT connect as the OS superuser for routine queries — use zdots_ro.
Migrations (zdots-ctx migrate) use ZDOTS_MIGRATION_URL (superuser) automatically.
`)

	head("Quick Reference")
	fmt.Printf(`Environment variables (set by providers/ai/llama-cpp.zsh in interactive zsh):
  ZDOTS_AI_ENDPOINT   AI server base URL   (default: %s)
  ZDOTS_AI_MODEL      Model alias          (default: local)
  ZDOTS_AI_PROFILE    Active model profile (default: standard)

Override at call time:
  ZDOTS_AI_ENDPOINT=http://other:11500 ai-query "prompt"

Platform control:
  zdots-ctl check                deep diagnostic (run when something is wrong)
  zdots-ctl up / down / reset    start / stop / restart the full platform
  zdots-ctl status --json        machine-readable aggregate status

AI capability discovery:
  llama-caps --md | pbcopy       brief any AI about this llama.cpp stack
  llama-caps --json              structured capability document
  llama-ctl config --json        server config + _discovery bootstrap block

Detailed documentation:
  docs/llama-cpp.md              Complete llama-ctl + API reference
  docs/otel-collector-guide.md   OTel setup, SDK examples, pipeline details
  AGENTS.md                      Full agent standards and workflow

`, aiEndpoint)
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}

func readTrimmedOr(path, fallback string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return fallback
	}
	s := strings.TrimSpace(string(b))
	if s == "" {
		return fallback
	}
	return s
}

func runCmd(timeout time.Duration, name string, args ...string) []byte {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	out, _ := exec.CommandContext(ctx, name, args...).Output()
	return out
}

func httpOK(url string, timeout time.Duration) bool {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(url)
	if err != nil {
		return false
	}
	_ = resp.Body.Close()
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

func httpBody(url string, timeout time.Duration) []byte {
	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(url)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil
	}
	var buf [64 * 1024]byte
	n, _ := resp.Body.Read(buf[:])
	return buf[:n]
}
