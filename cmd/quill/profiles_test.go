package main

import (
	"path/filepath"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/DaltonDayton/dotfiles/internal/runner"
)

// Every module a profile lists must survive both gates that run at apply time:
// FilterByHost (keyed on the profile name) and module.ValidFor (os/machine).
// This catches TOML drift the compiler can't — e.g. a module whose
// hosts=[...] or os/machine tags no longer match the profile it's listed in
// (the archlinux→arch-desktop rename that silently dropped gaming/razer).
func TestProfileModulesSurviveGates(t *testing.T) {
	root := filepath.Join("..", "..")
	mods, err := module.LoadAll(filepath.Join(root, "modules"))
	if err != nil {
		t.Fatal(err)
	}
	byName := map[string]*module.Module{}
	for _, m := range mods {
		byName[m.Name] = m
	}

	for _, pname := range []string{"arch-desktop", "arch-laptop", "wsl"} {
		prof, err := manifest.ParseProfile(filepath.Join(root, "profiles", pname+".toml"))
		if err != nil {
			t.Fatalf("%s: %v", pname, err)
		}
		for _, name := range prof.Modules {
			m := byName[name]
			if m == nil {
				t.Errorf("profile %s lists unknown module %q", pname, name)
				continue
			}
			if kept := runner.FilterByHost([]*module.Module{m}, prof.Name); len(kept) == 0 {
				t.Errorf("profile %s: module %q dropped by FilterByHost (hosts=%v vs profile %q)", pname, name, m.Hosts, prof.Name)
			}
			if !module.ValidFor(m, prof.OS, prof.Machine) {
				t.Errorf("profile %s: module %q invalid for os=%q machine=%q (module os=%v machine=%v)", pname, name, prof.OS, prof.Machine, m.OS, m.Machine)
			}
		}
	}
}
