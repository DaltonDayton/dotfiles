package tui

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func mkMod(name string, tags ...string) *module.Module {
	return &module.Module{Module: &manifest.Module{Name: name, Tags: tags}}
}

func TestGroupByTag(t *testing.T) {
	mods := []*module.Module{
		mkMod("git", "essential"),
		mkMod("zsh", "essential"),
		mkMod("neovim", "dev"),
		mkMod("misc"),
	}
	groups := GroupByTag(mods)
	if len(groups["essential"]) != 2 {
		t.Errorf("essential has %d", len(groups["essential"]))
	}
	if len(groups["dev"]) != 1 {
		t.Errorf("dev has %d", len(groups["dev"]))
	}
	if len(groups["uncategorized"]) != 1 {
		t.Errorf("uncategorized has %d", len(groups["uncategorized"]))
	}
}

func TestUnique(t *testing.T) {
	got := unique([]string{"a", "b", "a", "c", "b"})
	if len(got) != 3 {
		t.Fatalf("got %v", got)
	}
}
