package doctor

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCheckAdotsProfileContract(t *testing.T) {
	xdg := t.TempDir()
	adotsDir := filepath.Join(xdg, "adots")
	if err := os.MkdirAll(filepath.Join(adotsDir, "profiles"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(adotsDir, "profile"), []byte("powerstation\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(adotsDir, "profiles", "powerstation.conf"), []byte("ZDOTS_CONTEXT=home\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	s := &sectionResult{title: "test"}
	checkAdotsProfileContract(s, xdg)
	if s.pass != 1 || s.warn != 0 || s.fail != 0 {
		t.Fatalf("expected 1 pass / 0 warn / 0 fail, got pass=%d warn=%d fail=%d", s.pass, s.warn, s.fail)
	}

	// Missing matching .conf should warn
	if err := os.WriteFile(filepath.Join(adotsDir, "profile"), []byte("nonexistent\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	s2 := &sectionResult{title: "test"}
	checkAdotsProfileContract(s2, xdg)
	if s2.warn != 1 {
		t.Fatalf("expected 1 warn for missing profile .conf, got warn=%d", s2.warn)
	}
}

func TestCheckZdotsLocalContract(t *testing.T) {
	dir := t.TempDir()
	local := filepath.Join(dir, ".zdots.local")

	// Valid file
	if err := os.WriteFile(local, []byte("export ZDOTS_CONTEXT=home\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	s := &sectionResult{title: "test"}
	checkZdotsLocalContract(s, dir)
	if s.pass != 1 || s.fail != 0 || s.warn != 0 {
		t.Fatalf("expected clean pass, got pass=%d warn=%d fail=%d", s.pass, s.warn, s.fail)
	}

	// Forbidden DATABASE_URL should fail
	if err := os.WriteFile(local, []byte("export DATABASE_URL=postgresql://foo/bar\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	s2 := &sectionResult{title: "test"}
	checkZdotsLocalContract(s2, dir)
	if s2.fail != 1 {
		t.Fatalf("expected 1 fail for DATABASE_URL, got fail=%d", s2.fail)
	}
}

func TestCheckLogRotatePlistContract(t *testing.T) {
	home := t.TempDir()
	la := filepath.Join(home, "Library", "LaunchAgents")
	if err := os.MkdirAll(la, 0o700); err != nil {
		t.Fatal(err)
	}
	plist := filepath.Join(la, "com.zdots.log-rotate.plist")
	if err := os.WriteFile(plist, []byte("<plist><string>__HOME__</string></plist>"), 0o600); err != nil {
		t.Fatal(err)
	}
	s := &sectionResult{title: "test"}
	checkLogRotatePlistContract(s, home)
	if s.fail != 1 {
		t.Fatalf("expected 1 fail for unrendered __HOME__ placeholder, got fail=%d", s.fail)
	}
}
