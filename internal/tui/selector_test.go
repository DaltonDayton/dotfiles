package tui

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func mkMod(name string, tags ...string) *module.Module {
	return &module.Module{Module: &manifest.Module{Name: name, Tags: tags}}
}

func TestUnique(t *testing.T) {
	got := unique([]string{"a", "b", "a", "c", "b"})
	if len(got) != 3 {
		t.Fatalf("got %v", got)
	}
}
