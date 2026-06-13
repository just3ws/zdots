// Package scan loads and compiles the at-rest secret-detection registry.
//
// It deliberately mirrors the structure of the PHI Scrubber's registry
// (cmd/zdots-phi-scrub/internal/phi) — same RE2 compile-from-YAML engine — but
// is a separate domain: detect-only patterns for secrets committed to a repo,
// not the mutating PHI/credential scrub of the command/AI stream. The shared
// engine is the pattern; the registries stay separate (ADR-0002 lineage).
package scan

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"

	"gopkg.in/yaml.v3"
)

// Pattern is one entry from etc/secret-patterns.yaml.
type Pattern struct {
	Name  string `yaml:"name"`
	Regex string `yaml:"regex"`
}

type rawRegistry struct {
	Patterns []Pattern `yaml:"patterns"`
}

type compiledPattern struct {
	name string
	re   *regexp.Regexp
}

// Registry holds the compiled detect patterns, ready to match against input.
type Registry struct {
	patterns []compiledPattern
}

// Load reads etc/secret-patterns.yaml, compiles every pattern in RE2, and
// returns the Registry. Errors if the file is missing, the YAML is invalid, or
// any pattern fails to compile.
func Load() (*Registry, error) {
	path := patternsPath()
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("secret registry not found: %s: %w", path, err)
	}

	var raw rawRegistry
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if len(raw.Patterns) == 0 {
		return nil, fmt.Errorf("no patterns in %s", path)
	}

	r := &Registry{}
	for _, p := range raw.Patterns {
		re, err := regexp.Compile(p.Regex)
		if err != nil {
			return nil, fmt.Errorf("pattern %q failed to compile in RE2: %w", p.Name, err)
		}
		r.patterns = append(r.patterns, compiledPattern{name: p.Name, re: re})
	}
	return r, nil
}

// Match returns the name of the first matching pattern and the matched
// substring, or ("", "") when the line is clean.
func (r *Registry) Match(line []byte) (name, match string) {
	for _, p := range r.patterns {
		if loc := p.re.Find(line); loc != nil {
			return p.name, string(loc)
		}
	}
	return "", ""
}

// Count returns the number of compiled patterns.
func (r *Registry) Count() int { return len(r.patterns) }

// patternsPath resolves etc/secret-patterns.yaml, honoring ZDOTDIR (mirrors the
// PHI registry's resolution so both tools agree on where zdots config lives).
func patternsPath() string {
	if z := os.Getenv("ZDOTDIR"); z != "" {
		return filepath.Join(z, "etc", "secret-patterns.yaml")
	}
	return filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "secret-patterns.yaml")
}
