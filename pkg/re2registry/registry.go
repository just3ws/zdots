// Package re2registry is the shared RE2 pattern-registry engine for zdots
// scanners. Both the PHI Scrubber (cmd/zdots-phi-scrub) and the secret scanner
// (cmd/zdots-secret-scan) load YAML pattern files and compile them in RE2. The
// registries themselves stay separate — different domains, different YAML
// shapes (phi has replace/suppress; secret is detect-only) — but they must
// agree on the two things this package centralizes:
//
//   - ResolvePath: where registries live (ZDOTDIR-aware), so both tools look
//     in the same place.
//   - CompileAll: how patterns compile and validate in RE2, with one
//     consistent error message, so neither tool drifts on engine semantics.
//
// Domain registries unmarshal their own YAML, map down to []RawPattern for
// compilation, and rebuild their domain buckets (redact/suppress vs detect)
// from the ordered result.
package re2registry

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

// RawPattern is the minimal {name, regex} the engine needs to compile a
// pattern. Domain registries carry richer fields and map down to this.
type RawPattern struct {
	Name  string
	Regex string
}

// Compiled pairs a pattern's name with its compiled RE2 expression. Order is
// preserved so callers can zip results back to their domain metadata by index.
type Compiled struct {
	Name string
	RE   *regexp.Regexp
}

// CompileAll compiles every pattern in order, failing on the first that does
// not compile in RE2 (Go regexp), naming it for diagnostics.
func CompileAll(raws []RawPattern) ([]Compiled, error) {
	out := make([]Compiled, 0, len(raws))
	for _, r := range raws {
		re, err := regexp.Compile(r.Regex)
		if err != nil {
			return nil, fmt.Errorf("pattern %q failed to compile in RE2: %w", r.Name, err)
		}
		out = append(out, Compiled{Name: r.Name, RE: re})
	}
	return out, nil
}

// ResolvePath returns the absolute path to an etc/<filename> registry,
// honoring ZDOTDIR; otherwise ~/.config/zsh/etc/<filename>.
func ResolvePath(filename string) string {
	if z := os.Getenv("ZDOTDIR"); z != "" {
		return filepath.Join(z, "etc", filename)
	}
	return filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", filename)
}
