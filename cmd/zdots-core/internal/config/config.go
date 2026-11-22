package config

import (
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

// Get returns the value for key if non-empty, otherwise fallback.
func (e Env) Get(key, fallback string) string {
	if v, ok := e[key]; ok && v != "" {
		return v
	}
	return fallback
}

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
