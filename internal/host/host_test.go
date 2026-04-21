package host

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad_byHostname(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "laptop.toml"), []byte(`
name = "laptop"
aur_helper = "paru"
modules = ["git"]
`), 0o644)

	h, err := Load(dir, "laptop")
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if h.Name != "laptop" {
		t.Errorf("Name = %q, want laptop", h.Name)
	}
}

func TestLoad_missingHostFile(t *testing.T) {
	dir := t.TempDir()
	_, err := Load(dir, "unknown")
	if err == nil {
		t.Fatal("expected error for missing host file")
	}
}
