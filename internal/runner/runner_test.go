package runner

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func mod(name string, deps ...string) *module.Module {
	return &module.Module{
		Module: &manifest.Module{Name: name, DependsOn: deps},
		Dir:    "/tmp/" + name,
	}
}

func TestResolveDeps_transitive(t *testing.T) {
	all := []*module.Module{mod("a"), mod("b", "a"), mod("c", "b")}
	got, err := ResolveDeps(all, []string{"c"})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 {
		t.Fatalf("got %d, want 3", len(got))
	}
	want := []string{"a", "b", "c"}
	for i, m := range got {
		if m.Name != want[i] {
			t.Errorf("got[%d] = %s, want %s", i, m.Name, want[i])
		}
	}
}

func TestResolveDeps_cycle(t *testing.T) {
	all := []*module.Module{mod("a", "b"), mod("b", "a")}
	_, err := ResolveDeps(all, []string{"a"})
	if err == nil {
		t.Fatal("expected cycle error")
	}
}

func TestResolveDeps_unknownModule(t *testing.T) {
	all := []*module.Module{mod("a")}
	_, err := ResolveDeps(all, []string{"ghost"})
	if err == nil {
		t.Fatal("expected error for unknown module")
	}
}

func TestFilterByHost(t *testing.T) {
	all := []*module.Module{
		{Module: &manifest.Module{Name: "only-desktop", Hosts: []string{"desktop"}}},
		{Module: &manifest.Module{Name: "both"}},
	}
	got := FilterByHost(all, "laptop")
	if len(got) != 1 || got[0].Name != "both" {
		t.Errorf("got %v", got)
	}
}
