package state

import (
	"path/filepath"
	"testing"
)

func TestStateRoundTrip(t *testing.T) {
	p := filepath.Join(t.TempDir(), "sel.json")
	if s, err := LoadState(p); err != nil || s != nil {
		t.Fatalf("missing file: got %v,%v want nil,nil", s, err)
	}
	want := &Selection{OS: "ubuntu", Machine: "", Modules: []string{"git", "shell"}}
	if err := SaveState(p, want); err != nil {
		t.Fatal(err)
	}
	got, err := LoadState(p)
	if err != nil {
		t.Fatal(err)
	}
	if got.OS != "ubuntu" || len(got.Modules) != 2 || got.Machine != "" {
		t.Fatalf("got %+v", got)
	}
}
