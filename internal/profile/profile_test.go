package profile

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNormalizeOS(t *testing.T) {
	for in, want := range map[string]string{"wsl": "ubuntu", "ubuntu": "ubuntu", "arch": "arch"} {
		if got := NormalizeOS(in); got != want {
			t.Errorf("NormalizeOS(%q)=%q want %q", in, got, want)
		}
	}
}

func TestFileName(t *testing.T) {
	cases := []struct {
		os, mc, want string
		err          bool
	}{
		{"arch", "desktop", "arch-desktop", false},
		{"arch", "laptop", "arch-laptop", false},
		{"ubuntu", "", "wsl", false},
		{"ubuntu", "desktop", "wsl", false}, // machine ignored for ubuntu
		{"arch", "", "", true},              // arch needs a machine
		{"plan9", "", "", true},
	}
	for _, c := range cases {
		got, err := FileName(c.os, c.mc)
		if c.err && err == nil {
			t.Errorf("FileName(%q,%q) expected error", c.os, c.mc)
		}
		if !c.err && got != c.want {
			t.Errorf("FileName(%q,%q)=%q want %q", c.os, c.mc, got, c.want)
		}
	}
}

func TestLoad(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "wsl.toml"),
		[]byte("name=\"wsl\"\nos=\"ubuntu\"\nmodules=[\"git\"]\n"), 0o644)
	p, err := Load(dir, "ubuntu", "")
	if err != nil {
		t.Fatal(err)
	}
	if p.Name != "wsl" || p.OS != "ubuntu" {
		t.Fatalf("got %+v", p)
	}
}
