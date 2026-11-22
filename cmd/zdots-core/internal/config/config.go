package config

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// envDefault matches a whole ${NAME:-literal} value.
var envDefault = regexp.MustCompile(`^\$\{([A-Za-z_][A-Za-z0-9_]*):-([^$` + "`" + `}]*)\}$`)

// Env holds resolved platform configuration values with deterministic precedence:
// process environment > .zdots.env (top-level) > etc/defaults.env.
type Env map[string]string

// Zdotdir returns $ZDOTDIR or ~/.config/zsh.
func Zdotdir() string {
	if v := os.Getenv("ZDOTDIR"); v != "" {
		return v
	}
	home, _ := os.UserHomeDir()
	if home == "" {
		return ""
	}
	return filepath.Join(home, ".config", "zsh")
}

// Get returns the value for key if non-empty, otherwise fallback.
func (e Env) Get(key, fallback string) string {
	if v, ok := e[key]; ok && v != "" {
		return v
	}
	return fallback
}

func bracketIPv6(h string) string {
	if strings.Contains(h, ":") && !strings.HasPrefix(h, "[") {
		return "[" + h + "]"
	}
	return h
}

func (e Env) endpoint(epKey, hostKey, portKey, defaultHost, defaultPort string) string {
	if v := os.Getenv(epKey); v != "" {
		return v
	}
	if os.Getenv(hostKey) != "" || os.Getenv(portKey) != "" {
		h := bracketIPv6(e.Get(hostKey, defaultHost))
		p := e.Get(portKey, defaultPort)
		return fmt.Sprintf("http://%s:%s", h, p)
	}
	if v := e.Get(epKey, ""); v != "" {
		return v
	}
	return fmt.Sprintf("http://%s:%s", bracketIPv6(e.Get(hostKey, defaultHost)), e.Get(portKey, defaultPort))
}

func (e Env) AIEndpoint() string {
	return e.endpoint("ZDOTS_AI_ENDPOINT", "ZDOTS_AI_HOST", "ZDOTS_AI_PORT", "127.0.0.1", "11500")
}

func (e Env) EmbedEndpoint() string {
	if v := os.Getenv("ZDOTS_AI_EMBED_ENDPOINT"); v != "" {
		return v
	}
	portKey := "ZDOTS_AI_EMBED_PORT"
	if os.Getenv("ZDOTS_EMBED_PORT") != "" {
		portKey = "ZDOTS_EMBED_PORT"
	}
	return e.endpoint("ZDOTS_AI_EMBED_ENDPOINT", "ZDOTS_AI_EMBED_HOST", portKey, "127.0.0.1", "11501")
}

func (e Env) O2Endpoint() string {
	return e.endpoint("ZDOTS_O2_ENDPOINT", "ZDOTS_O2_HOST", "ZDOTS_O2_PORT", "127.0.0.1", "5080")
}

func (e Env) JaegerEndpoint() string {
	return e.endpoint("ZDOTS_JAEGER_ENDPOINT", "ZDOTS_JAEGER_HOST", "ZDOTS_JAEGER_UI_PORT", "127.0.0.1", "16686")
}

func (e Env) OTLPEndpoint() string {
	if v := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"); v != "" {
		return v
	}
	if v := os.Getenv("ZDOTS_OTLP_ENDPOINT"); v != "" {
		return v
	}
	return e.endpoint("ZDOTS_OTEL_ENDPOINT", "ZDOTS_OTEL_HOST", "ZDOTS_OTEL_HTTP_PORT", "127.0.0.1", "4318")
}

func (e Env) RedisHost() string { return e.Get("ZDOTS_REDIS_HOST", "127.0.0.1") }
func (e Env) RedisPort() string { return e.Get("ZDOTS_REDIS_PORT", "6379") }

// Load reads os.Environ() and fills missing keys from .zdots.env (top-level)
// and etc/defaults.env in zdotdir. Process environment always wins.
func Load(zdotdir string) Env {
	m := make(Env)
	for _, entry := range os.Environ() {
		if k, v, ok := strings.Cut(entry, "="); ok {
			m[k] = v
		}
	}
	if zdotdir == "" {
		return m
	}
	// .zdots.env before etc/defaults.env so .zdots.env overrides defaults,
	// while os.Environ() overrides both.
	loadFileInto(m, filepath.Join(zdotdir, ".zdots.env"))
	loadFileInto(m, filepath.Join(zdotdir, "etc", "defaults.env"))
	return m
}

// LoadFile reads os.Environ() and fills missing keys from a single env file.
func LoadFile(path string) Env {
	m := make(Env)
	for _, entry := range os.Environ() {
		if k, v, ok := strings.Cut(entry, "="); ok {
			m[k] = v
		}
	}
	loadFileInto(m, path)
	return m
}

func loadFileInto(m Env, path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	depth := 0
	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		switch word, _, _ := strings.Cut(line, " "); strings.TrimSuffix(word, ";") {
		case "if", "case":
			depth++
			continue
		case "fi", "esac":
			if depth > 0 {
				depth--
			}
			continue
		}
		if depth > 0 {
			continue
		}
		line = strings.TrimPrefix(line, "export ")
		line = strings.TrimSpace(line)
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(v)
		if len(v) >= 2 && ((v[0] == '"' && v[len(v)-1] == '"') || (v[0] == '\'' && v[len(v)-1] == '\'')) {
			v = v[1 : len(v)-1]
		}
		if sm := envDefault.FindStringSubmatch(v); sm != nil {
			v = sm[2]
			if ev := m[sm[1]]; ev != "" {
				v = ev
			}
		} else if strings.ContainsAny(v, "$`") {
			continue
		}
		if k != "" && m[k] == "" {
			m[k] = v
		}
	}
}
