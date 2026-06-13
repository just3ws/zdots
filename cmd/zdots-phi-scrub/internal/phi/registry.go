package phi

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	"zdots/pkg/re2registry"
)

// Pattern represents a single PHI/credential pattern from etc/phi-patterns.yaml
type Pattern struct {
	Name     string `yaml:"name"`
	Regex    string `yaml:"regex"`
	Replace  string `yaml:"replace"`
	Suppress bool   `yaml:"suppress"`
	Weight   *int   `yaml:"weight,omitempty"`
}

// rawRegistry is the on-disk structure from etc/phi-patterns.yaml
type rawRegistry struct {
	Patterns []Pattern `yaml:"patterns"`
}

// Compiled holds the loaded and compiled patterns, ready for scrubbing.
// Patterns are split into two buckets:
//   - redact: non-suppress patterns that are applied sequentially
//   - suppress: patterns that cause a hard failure if matched
type Compiled struct {
	redact   []compiledPattern
	suppress []*regexp.Regexp
}

type compiledPattern struct {
	name string // for metrics/observability
	re   *regexp.Regexp
	rep  string
}

// Load reads etc/phi-patterns.yaml, compiles all patterns in RE2, and returns a Compiled registry.
// Returns an error if the file is missing, YAML is invalid, or any pattern fails to compile.
func Load() (*Compiled, error) {
	path := patternsPath()
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("registry not found: %s: %w", path, err)
	}

	var raw rawRegistry
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}

	if len(raw.Patterns) == 0 {
		return nil, fmt.Errorf("no patterns in %s", path)
	}

	// Compile via the shared RE2 engine; order is preserved so we can zip the
	// compiled regexps back to each pattern's suppress/replace metadata.
	raws := make([]re2registry.RawPattern, len(raw.Patterns))
	for i, p := range raw.Patterns {
		raws[i] = re2registry.RawPattern{Name: p.Name, Regex: p.Regex}
	}
	compiled, err := re2registry.CompileAll(raws)
	if err != nil {
		return nil, err
	}

	c := &Compiled{}
	for i, p := range raw.Patterns {
		re := compiled[i].RE
		if p.Suppress {
			c.suppress = append(c.suppress, re)
		} else {
			// Translate sed-style replacement (\1) to Go RE2 style ($1)
			c.redact = append(c.redact, compiledPattern{
				name: p.Name,
				re:   re,
				rep:  translateReplacement(p.Replace),
			})
		}
	}

	return c, nil
}

// translateReplacement converts sed-style backreferences (\1) to Go RE2 style ($1).
// First escapes literal $ to $$ so it's not interpreted as a group reference.
func translateReplacement(s string) string {
	// Escape any literal $ first
	s = strings.ReplaceAll(s, "$", "$$")

	// Convert \1, \2, ... to $1, $2, ...
	// Do it carefully: sed uses \N, Go uses $N
	for i := 9; i >= 1; i-- {
		// Replace from 9 to 1 to avoid double-replacement (e.g. \10 -> \1 + 0)
		old := fmt.Sprintf("\\%d", i)
		new := fmt.Sprintf("$%d", i)
		s = strings.ReplaceAll(s, old, new)
	}

	return s
}

// IsSuppressed returns true if the input matches any suppress-flagged pattern.
// This is the fast path used by shell hooks to avoid forking the scrubber.
func (c *Compiled) IsSuppressed(input []byte) bool {
	for _, re := range c.suppress {
		if re.Match(input) {
			return true
		}
	}
	return false
}

// Scrub applies all redaction patterns to the input and returns the redacted result.
// Patterns are applied in the order they appear in the registry.
// Does not check for suppress patterns — that is the caller's responsibility.
func (c *Compiled) Scrub(input []byte) []byte {
	output := input
	for _, p := range c.redact {
		output = p.re.ReplaceAll(output, []byte(p.rep))
	}
	return output
}

// PatternCount returns the number of redact and suppress patterns loaded.
func (c *Compiled) PatternCount() (redact, suppress int) {
	return len(c.redact), len(c.suppress)
}

// SuppressPatternNames returns the names of all suppress-flagged patterns.
// Used for observability and debugging.
func (c *Compiled) SuppressPatternNames() []string {
	raw, err := loadRaw()
	if err != nil {
		return nil
	}
	var names []string
	for _, p := range raw.Patterns {
		if p.Suppress {
			names = append(names, p.Name)
		}
	}
	return names
}

// loadRaw reads and parses the registry without compiling patterns (used for metadata).
func loadRaw() (*rawRegistry, error) {
	path := patternsPath()
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("registry not found: %s: %w", path, err)
	}
	var raw rawRegistry
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	return &raw, nil
}

// patternsPath returns the absolute path to etc/phi-patterns.yaml.
// Respects ZDOTDIR environment variable if set; otherwise defaults to ~/.config/zsh.
func patternsPath() string {
	return re2registry.ResolvePath("phi-patterns.yaml")
}
