package runner

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func TestBuildActions_PackageManagerGatedByOS(t *testing.T) {
	m := &module.Module{
		Dir: t.TempDir(),
		Module: &manifest.Module{
			Name: "x",
			Packages: []manifest.Packages{
				{Manager: "pacman", Names: []string{"fd"}},
				{Manager: "apt", Names: []string{"fd-find"}},
			},
		},
	}
	host := &manifest.Host{Name: "h"}

	arch, err := BuildActions(m, host, "arch")
	if err != nil {
		t.Fatal(err)
	}
	if got := pkgManagers(arch); len(got) != 1 || got[0] != "pacman" {
		t.Fatalf("arch managers = %v, want [pacman]", got)
	}

	ubuntu, err := BuildActions(m, host, "ubuntu")
	if err != nil {
		t.Fatal(err)
	}
	if got := pkgManagers(ubuntu); len(got) != 1 || got[0] != "apt" {
		t.Fatalf("ubuntu managers = %v, want [apt]", got)
	}
}

func TestBuildActions_OSGateOnNonPackageActions(t *testing.T) {
	m := &module.Module{
		Dir: t.TempDir(),
		Module: &manifest.Module{
			Name: "x",
			Commands: []manifest.Command{
				{Run: "echo arch", OS: []string{"arch"}},
				{Run: "echo ubuntu", OS: []string{"ubuntu"}},
				{Run: "echo both"},
			},
		},
	}
	host := &manifest.Host{Name: "h"}

	got, err := BuildActions(m, host, "ubuntu")
	if err != nil {
		t.Fatal(err)
	}
	var runs []string
	for _, a := range got {
		if c, ok := a.(*action.Command); ok {
			runs = append(runs, c.Run)
		}
	}
	want := []string{"echo ubuntu", "echo both"}
	if len(runs) != len(want) || runs[0] != want[0] || runs[1] != want[1] {
		t.Fatalf("commands = %v, want %v", runs, want)
	}
}

// Regression: an Arch-only module (no os fields, only pacman) must produce the
// exact same actions on os="arch" as before OS gating existed.
func TestBuildActions_ArchRegression(t *testing.T) {
	m := &module.Module{
		Dir: t.TempDir(),
		Module: &manifest.Module{
			Name:     "x",
			Packages: []manifest.Packages{{Manager: "pacman", Names: []string{"git"}}},
			Commands: []manifest.Command{{Run: "echo hi"}},
		},
	}
	got, err := BuildActions(m, &manifest.Host{Name: "h"}, "arch")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 actions, got %d", len(got))
	}
}

// pkgManagers extracts the Manager of every Packages action, in order.
func pkgManagers(acts []action.Action) []string {
	var out []string
	for _, a := range acts {
		if p, ok := a.(*action.Packages); ok {
			out = append(out, p.Manager)
		}
	}
	return out
}

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
	acts, err := BuildActions(m, host, "arch")
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
	acts, err := BuildActions(m, host, "arch")
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

func TestBuildActions_managerDefaultsToYay(t *testing.T) {
	cases := map[string]string{
		"":       "yay", // unset → default to yay (handles repos + AUR)
		"aur":    "yay", // logical alias kept for module readability
		"pacman": "pacman",
		"yay":    "yay",
	}
	for input, want := range cases {
		m := &module.Module{
			Dir: "/tmp",
			Module: &manifest.Module{
				Name:     "ex",
				Packages: []manifest.Packages{{Manager: input, Names: []string{"x"}}},
			},
		}
		host := &manifest.Host{Name: "h"}
		acts, err := BuildActions(m, host, "arch")
		if err != nil {
			t.Fatalf("input=%q: %v", input, err)
		}
		pkg, ok := acts[0].(*action.Packages)
		if !ok {
			t.Fatalf("input=%q: got %T", input, acts[0])
		}
		if pkg.Manager != want {
			t.Errorf("input=%q: Manager = %q, want %q", input, pkg.Manager, want)
		}
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
	acts, err := BuildActions(m, host, "arch")
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
