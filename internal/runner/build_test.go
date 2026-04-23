package runner

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func TestBuildActions_filtersByHostAndExpandsSymlinks(t *testing.T) {
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "files"), 0o755)
	os.WriteFile(filepath.Join(dir, "files", "a.conf"), []byte("x"), 0o644)

	m := &module.Module{
		Dir: dir,
		Module: &manifest.Module{
			Name: "ex",
			Symlinks: []manifest.Symlink{
				{Src: "files/a.conf", Dst: "/tmp/a"},
				{Src: "files/a.conf", Dst: "/tmp/d", Hosts: []string{"desktop"}},
			},
		},
	}
	host := &manifest.Host{Name: "laptop"}
	acts, err := BuildActions(m, host)
	if err != nil {
		t.Fatal(err)
	}
	if len(acts) != 1 {
		t.Fatalf("got %d actions, want 1", len(acts))
	}
	if _, ok := acts[0].(*action.Symlink); !ok {
		t.Errorf("got %T, want *action.Symlink", acts[0])
	}
}

func TestBuildActions_rendersTemplateSymlink(t *testing.T) {
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "files"), 0o755)
	tmpl := `email = {{ .Vars.email }}`
	os.WriteFile(filepath.Join(dir, "files", ".gitconfig.tmpl"), []byte(tmpl), 0o644)

	m := &module.Module{
		Dir: dir,
		Module: &manifest.Module{
			Name: "git",
			Symlinks: []manifest.Symlink{
				{Src: "files/.gitconfig.tmpl", Dst: "/tmp/.gitconfig"},
			},
		},
	}
	host := &manifest.Host{Name: "host", Vars: map[string]string{"email": "a@b"}}
	acts, err := BuildActions(m, host)
	if err != nil {
		t.Fatal(err)
	}
	if len(acts) != 1 {
		t.Fatalf("got %d, want 1", len(acts))
	}
	rendered, err := os.ReadFile(filepath.Join(dir, "files", ".gitconfig"))
	if err != nil {
		t.Fatalf("rendered file missing: %v", err)
	}
	if string(rendered) != "email = a@b" {
		t.Errorf("rendered = %q", rendered)
	}
}

func TestBuildActions_aurManagerResolvesToHostHelper(t *testing.T) {
	m := &module.Module{
		Dir: "/tmp",
		Module: &manifest.Module{
			Name:     "asdf",
			Packages: []manifest.Packages{{Manager: "aur", Names: []string{"asdf-vm"}}},
		},
	}
	host := &manifest.Host{Name: "h", AURHelper: "paru"}
	acts, err := BuildActions(m, host)
	if err != nil {
		t.Fatal(err)
	}
	if len(acts) != 1 {
		t.Fatalf("got %d, want 1", len(acts))
	}
	pkg, ok := acts[0].(*action.Packages)
	if !ok {
		t.Fatalf("got %T, want *action.Packages", acts[0])
	}
	if pkg.Manager != "paru" {
		t.Errorf("Manager = %q, want paru", pkg.Manager)
	}
}

func TestBuildActions_aurManagerWithoutHostHelperErrors(t *testing.T) {
	m := &module.Module{
		Dir: "/tmp",
		Module: &manifest.Module{
			Name:     "asdf",
			Packages: []manifest.Packages{{Manager: "aur", Names: []string{"asdf-vm"}}},
		},
	}
	host := &manifest.Host{Name: "h"}
	if _, err := BuildActions(m, host); err == nil {
		t.Fatal("expected error when host has no aur_helper")
	}
}

func TestBuildActions_respectsOrder(t *testing.T) {
	m := &module.Module{
		Dir: "/tmp",
		Module: &manifest.Module{
			Name:        "ex",
			Directories: []manifest.Directory{{Path: "/tmp/d", Mode: "0755"}},
			Packages:    []manifest.Packages{{Manager: "pacman", Names: []string{"git"}}},
			Commands:    []manifest.Command{{Run: "echo hi"}},
			Services:    []manifest.Service{{Name: "u", Scope: "user", State: "enabled"}},
		},
	}
	host := &manifest.Host{Name: "h"}
	acts, err := BuildActions(m, host)
	if err != nil {
		t.Fatal(err)
	}
	if len(acts) != 4 {
		t.Fatalf("got %d", len(acts))
	}
	if _, ok := acts[0].(*action.Directory); !ok {
		t.Errorf("acts[0] = %T, want *Directory", acts[0])
	}
	if _, ok := acts[1].(*action.Packages); !ok {
		t.Errorf("acts[1] = %T, want *Packages", acts[1])
	}
	if _, ok := acts[2].(*action.Command); !ok {
		t.Errorf("acts[2] = %T, want *Command", acts[2])
	}
	if _, ok := acts[3].(*action.Service); !ok {
		t.Errorf("acts[3] = %T, want *Service", acts[3])
	}
}
