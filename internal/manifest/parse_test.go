package manifest

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseModule_happyPath(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "module.toml")
	content := `
name = "git"
description = "Git + global gitconfig"
tags = ["essential"]
depends_on = []

[[packages]]
manager = "pacman"
names = ["git"]

[[symlinks]]
src = "files/.gitconfig"
dst = "~/.gitconfig"
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	m, err := ParseModule(path)
	if err != nil {
		t.Fatalf("ParseModule: %v", err)
	}
	if m.Name != "git" {
		t.Errorf("Name = %q, want git", m.Name)
	}
	if len(m.Packages) != 1 || m.Packages[0].Manager != "pacman" {
		t.Errorf("Packages = %+v", m.Packages)
	}
	if len(m.Symlinks) != 1 || m.Symlinks[0].Dst != "~/.gitconfig" {
		t.Errorf("Symlinks = %+v", m.Symlinks)
	}
}

func TestParseModule_missingNameIsError(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "module.toml")
	os.WriteFile(path, []byte(`description = "no name here"`), 0o644)

	if _, err := ParseModule(path); err == nil {
		t.Fatal("expected error when module is missing required field 'name'")
	}
}

func TestParseHost_happyPath(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "laptop.toml")
	content := `
name = "laptop"
modules = ["git", "zsh"]

[vars]
monitor = "eDP-1,preferred,auto,1.0"
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	h, err := ParseHost(path)
	if err != nil {
		t.Fatalf("ParseHost: %v", err)
	}
	if h.Name != "laptop" {
		t.Errorf("Name = %q, want laptop", h.Name)
	}
	if h.Vars["monitor"] == "" {
		t.Errorf("Vars = %+v", h.Vars)
	}
}

func TestParseHost_emptyVarsMapIsNonNil(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "minimal.toml")
	os.WriteFile(path, []byte(`name = "minimal"`), 0o644)

	h, err := ParseHost(path)
	if err != nil {
		t.Fatal(err)
	}
	// why: downstream template code does h.Vars[...] lookups; a nil map would
	// panic on write, and forcing it non-nil lets callers append freely.
	if h.Vars == nil {
		t.Error("Vars map should be non-nil even when TOML omits [vars]")
	}
}

func TestParseModule_OSField(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "module.toml")
	if err := os.WriteFile(p, []byte(`
name = "x"
[[commands]]
run = "echo hi"
os = ["ubuntu"]
`), 0o644); err != nil {
		t.Fatal(err)
	}
	m, err := ParseModule(p)
	if err != nil {
		t.Fatal(err)
	}
	if len(m.Commands) != 1 || len(m.Commands[0].OS) != 1 || m.Commands[0].OS[0] != "ubuntu" {
		t.Fatalf("OS not parsed: %+v", m.Commands)
	}
}

func TestParseModule_todos(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "module.toml")
	content := `
name = "git"

[[todos]]
message = "Run gh auth login"
check = "gh auth status"

[[todos]]
message = "Always shown"
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	m, err := ParseModule(path)
	if err != nil {
		t.Fatalf("ParseModule: %v", err)
	}
	if len(m.Todos) != 2 {
		t.Fatalf("Todos = %+v, want 2", m.Todos)
	}
	if m.Todos[0].Message != "Run gh auth login" || m.Todos[0].Check != "gh auth status" {
		t.Errorf("Todos[0] = %+v", m.Todos[0])
	}
	if m.Todos[1].Check != "" {
		t.Errorf("Todos[1].Check = %q, want empty", m.Todos[1].Check)
	}
}
