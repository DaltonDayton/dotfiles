package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsurePathLine_appendsWhenMissing(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc")
	os.WriteFile(rc, []byte("# zshrc\nalias ls=eza\n"), 0o644)

	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if !modified {
		t.Fatal("expected file to be modified")
	}
	out, _ := os.ReadFile(rc)
	if !strings.Contains(string(out), ".local/bin") {
		t.Errorf("expected .local/bin in output, got %q", out)
	}
}

func TestEnsurePathLine_skipsWhenPresent(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc")
	os.WriteFile(rc, []byte(`export PATH="$HOME/.local/bin:$PATH"`+"\n"), 0o644)

	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if modified {
		t.Fatal("expected idempotent no-op when line already present")
	}
}

func TestEnsurePathLine_createsWhenMissing(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc")
	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if !modified {
		t.Fatal("expected modified=true for new file")
	}
	if _, err := os.Stat(rc); err != nil {
		t.Fatal(err)
	}
}

func TestEnsurePathLine_ignoresCommentedLine(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc")
	os.WriteFile(rc, []byte(`# export PATH="$HOME/.local/bin:$PATH"`+"\n"), 0o644)
	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if !modified {
		t.Fatal("commented-out line should not count")
	}
}
