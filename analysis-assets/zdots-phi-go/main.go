// zdots-phi (Go prototype) — PHI/credential scrubber sharing the collector's RE2
// engine. Loads the single registry (etc/phi-patterns.yaml) and mirrors the
// phi_scrub contract from lib/phi_scrubber.bash:
//
//   scrub        stdin -> stdout, redact in registry order; if input matches a
//                suppress-flagged pattern, print nothing and exit 1 (fail hard).
//   suppressed?  exit 0 if stdin matches a suppress pattern, else 1 (no output).
//   check        compile the registry, report counts, exit non-zero on any bad
//                pattern (fail loud — closes the silent-drift gap).
//
// One regex engine (Go RE2) for the shell layer AND the OTel collector, with
// linear-time matching (no catastrophic backtracking on adversarial input).
package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

type pattern struct {
	Name     string `yaml:"name"`
	Regex    string `yaml:"regex"`
	Replace  string `yaml:"replace"`
	Suppress bool   `yaml:"suppress"`
}

type registry struct {
	Patterns []pattern `yaml:"patterns"`
}

// translateRepl converts a sed-style replacement (\1) to Go RE2 ($1) semantics,
// escaping any literal $ first so it is not read as a group reference.
var groupRef = regexp.MustCompile(`\\([0-9])`)

func translateRepl(s string) string {
	s = strings.ReplaceAll(s, "$", "$$")
	return groupRef.ReplaceAllString(s, "$${$1}")
}

func patternsPath() string {
	if z := os.Getenv("ZDOTDIR"); z != "" {
		return filepath.Join(z, "etc", "phi-patterns.yaml")
	}
	// default: ../../etc relative to this prototype dir
	return filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "phi-patterns.yaml")
}

type compiled struct {
	redact   []struct {
		re  *regexp.Regexp
		rep string
	}
	suppress []*regexp.Regexp
}

func load() (*compiled, error) {
	path := patternsPath()
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("registry not found: %s: %w", path, err)
	}
	var reg registry
	if err := yaml.Unmarshal(data, &reg); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if len(reg.Patterns) == 0 {
		return nil, fmt.Errorf("no patterns in %s", path)
	}
	c := &compiled{}
	for _, p := range reg.Patterns {
		re, err := regexp.Compile(p.Regex) // RE2 — fails loud on a bad pattern
		if err != nil {
			return nil, fmt.Errorf("pattern %q failed to compile in RE2: %w", p.Name, err)
		}
		if p.Suppress {
			c.suppress = append(c.suppress, re)
		} else {
			c.redact = append(c.redact, struct {
				re  *regexp.Regexp
				rep string
			}{re, translateRepl(p.Replace)})
		}
	}
	return c, nil
}

func (c *compiled) isSuppressed(b []byte) bool {
	for _, re := range c.suppress {
		if re.Match(b) {
			return true
		}
	}
	return false
}

func (c *compiled) scrub(b []byte) []byte {
	for _, r := range c.redact {
		b = r.re.ReplaceAll(b, []byte(r.rep))
	}
	return b
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: zdots-phi {scrub|suppressed?|check}")
		os.Exit(2)
	}
	c, err := load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "zdots-phi: %v\n", err)
		os.Exit(1)
	}

	switch os.Args[1] {
	case "check":
		fmt.Fprintf(os.Stderr, "zdots-phi: OK — %d redact + %d suppress pattern(s) compile in RE2\n",
			len(c.redact), len(c.suppress))
		return

	case "suppressed?":
		in, _ := io.ReadAll(os.Stdin)
		if c.isSuppressed(in) {
			os.Exit(0)
		}
		os.Exit(1)

	case "scrub":
		in, _ := io.ReadAll(os.Stdin)
		if c.isSuppressed(in) {
			fmt.Fprintln(os.Stderr, "zdots-phi: suppress-flagged pattern in input — refusing to process")
			os.Exit(1)
		}
		os.Stdout.Write(c.scrub(in))
		return

	default:
		fmt.Fprintf(os.Stderr, "zdots-phi: unknown command: %s\n", os.Args[1])
		os.Exit(2)
	}
}
