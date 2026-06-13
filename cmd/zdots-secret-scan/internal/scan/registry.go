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
	"regexp"

	"gopkg.in/yaml.v3"

	"zdots/pkg/re2registry"
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

	// Compile via the shared RE2 engine (same loader the PHI Scrubber uses).
	raws := make([]re2registry.RawPattern, len(raw.Patterns))
	for i, p := range raw.Patterns {
		raws[i] = re2registry.RawPattern{Name: p.Name, Regex: p.Regex}
	}
	compiled, err := re2registry.CompileAll(raws)
	if err != nil {
		return nil, err
	}

	r := &Registry{}
	for _, c := range compiled {
		r.patterns = append(r.patterns, compiledPattern{name: c.Name, re: c.RE})
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

// patternsPath resolves etc/secret-patterns.yaml via the shared engine, so this
// tool and the PHI Scrubber agree on where zdots registries live.
func patternsPath() string {
	return re2registry.ResolvePath("secret-patterns.yaml")
}
