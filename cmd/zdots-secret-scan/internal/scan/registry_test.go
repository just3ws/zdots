package scan

import (
	"os"
	"path/filepath"
	"testing"
)

func registryExists() bool {
	p := filepath.Join(os.Getenv("HOME"), ".config", "zsh", "etc", "secret-patterns.yaml")
	if z := os.Getenv("ZDOTDIR"); z != "" {
		p = filepath.Join(z, "etc", "secret-patterns.yaml")
	}
	_, err := os.Stat(p)
	return err == nil
}

func TestLoad_CompilesPatterns(t *testing.T) {
	if !registryExists() {
		t.Skip("secret-patterns.yaml not found")
	}
	r, err := Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if r.Count() == 0 {
		t.Fatal("expected at least one pattern")
	}
}

func TestMatch_DetectsAndIgnores(t *testing.T) {
	if !registryExists() {
		t.Skip("secret-patterns.yaml not found")
	}
	r, err := Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	cases := []struct {
		name string
		in   string
		want bool
	}{
		{"aws key", "AKIAIOSFODNN7EXAMPLE", true},
		{"github token", "ghp_0123456789abcdefghijklmnopqrstuvwx", true},
		{"private key header", "-----BEGIN RSA PRIVATE KEY-----", true},
		{"clean prose", "this is a perfectly normal line of text", false},
		{"clean code", "func main() { fmt.Println(\"hi\") }", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			name, _ := r.Match([]byte(c.in))
			got := name != ""
			if got != c.want {
				t.Errorf("Match(%q) matched=%v (pattern=%q), want %v", c.in, got, name, c.want)
			}
		})
	}
}
