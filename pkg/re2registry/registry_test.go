package re2registry

import (
	"path/filepath"
	"testing"
)

func TestCompileAll_Success(t *testing.T) {
	raws := []RawPattern{
		{Name: "ssn", Regex: `\d{3}-\d{2}-\d{4}`},
		{Name: "word", Regex: `[a-z]+`},
	}
	got, err := CompileAll(raws)
	if err != nil {
		t.Fatalf("CompileAll: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("got %d compiled, want 2", len(got))
	}
	if got[0].Name != "ssn" || !got[0].RE.MatchString("123-45-6789") {
		t.Errorf("first pattern did not compile/match as expected")
	}
	// Order preserved for index-zip by callers.
	if got[1].Name != "word" {
		t.Errorf("order not preserved: got[1].Name=%q", got[1].Name)
	}
}

func TestCompileAll_BadPatternNamed(t *testing.T) {
	raws := []RawPattern{
		{Name: "ok", Regex: `abc`},
		{Name: "broken", Regex: `[unterminated`},
	}
	_, err := CompileAll(raws)
	if err == nil {
		t.Fatal("expected error on bad pattern")
	}
	if want := `"broken"`; !contains(err.Error(), want) {
		t.Errorf("error %q should name the failing pattern %s", err, want)
	}
}

func TestResolvePath_HonorsZDOTDIR(t *testing.T) {
	t.Setenv("ZDOTDIR", "/tmp/zd")
	if got, want := ResolvePath("phi-patterns.yaml"), filepath.Join("/tmp/zd", "etc", "phi-patterns.yaml"); got != want {
		t.Errorf("ResolvePath = %q, want %q", got, want)
	}
}

func TestResolvePath_DefaultsToHome(t *testing.T) {
	t.Setenv("ZDOTDIR", "")
	t.Setenv("HOME", "/home/u")
	if got, want := ResolvePath("secret-patterns.yaml"), filepath.Join("/home/u", ".config", "zsh", "etc", "secret-patterns.yaml"); got != want {
		t.Errorf("ResolvePath = %q, want %q", got, want)
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
