package state

import (
	"path/filepath"
	"testing"
)

func TestLoadSelection_missingFileReturnsEmpty(t *testing.T) {
	dir := t.TempDir()
	got, err := LoadSelection(filepath.Join(dir, "selection.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Errorf("expected empty, got %v", got)
	}
}

func TestSaveAndLoadRoundtrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "selection.json")
	want := []string{"git", "zsh", "hyprland"}
	if err := SaveSelection(path, want); err != nil {
		t.Fatal(err)
	}
	got, err := LoadSelection(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for i, m := range got {
		if m != want[i] {
			t.Errorf("got[%d]=%q, want %q", i, m, want[i])
		}
	}
}

func TestSaveSelection_createsParentDir(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "dir", "sel.json")
	if err := SaveSelection(path, []string{"x"}); err != nil {
		t.Fatal(err)
	}
}
