package module

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

func mod(name string, os, machine []string) *Module {
	return &Module{Module: &manifest.Module{Name: name, OS: os, Machine: machine}}
}

func TestValidFor(t *testing.T) {
	cases := []struct {
		name           string
		os, machine    []string
		pickOS, pickMc string
		want           bool
	}{
		{"cross-platform on ubuntu", nil, nil, "ubuntu", "", true},
		{"arch-only on ubuntu", []string{"arch"}, nil, "ubuntu", "", false},
		{"arch-only on arch", []string{"arch"}, nil, "arch", "desktop", true},
		{"desktop-only on laptop", []string{"arch"}, []string{"desktop"}, "arch", "laptop", false},
		{"desktop-only on desktop", []string{"arch"}, []string{"desktop"}, "arch", "desktop", true},
		{"machine skipped when pick empty (wsl)", nil, []string{"desktop"}, "ubuntu", "", true},
	}
	for _, c := range cases {
		if got := ValidFor(mod(c.name, c.os, c.machine), c.pickOS, c.pickMc); got != c.want {
			t.Errorf("%s: ValidFor=%v want %v", c.name, got, c.want)
		}
	}
}

func TestFilterValidAndPreselect(t *testing.T) {
	mods := []*Module{
		mod("git", nil, nil),
		mod("hyprland", []string{"arch"}, nil),
		mod("gaming", []string{"arch"}, []string{"desktop"}),
	}
	got := FilterValid(mods, "ubuntu", "")
	if len(got) != 1 || got[0].Name != "git" {
		t.Fatalf("FilterValid ubuntu = %v", names(got))
	}
	pre := Preselect(got, []string{"git", "hyprland"})
	if !pre["git"] || pre["hyprland"] {
		t.Fatalf("Preselect = %v (want git only; hyprland not in valid set)", pre)
	}
}

func names(ms []*Module) []string {
	out := []string{}
	for _, m := range ms {
		out = append(out, m.Name)
	}
	return out
}
