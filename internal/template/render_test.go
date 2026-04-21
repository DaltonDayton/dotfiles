package template

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

func TestRender_substitutesHostVars(t *testing.T) {
	h := &manifest.Host{
		Name: "laptop",
		Vars: map[string]string{"monitor": "eDP-1,preferred,auto,1.0"},
	}
	got, err := Render("monitor = {{ .Vars.monitor }}", h)
	if err != nil {
		t.Fatalf("Render: %v", err)
	}
	want := "monitor = eDP-1,preferred,auto,1.0"
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestRender_exposesHostName(t *testing.T) {
	h := &manifest.Host{Name: "desktop"}
	got, err := Render("host={{ .Name }}", h)
	if err != nil {
		t.Fatalf("Render: %v", err)
	}
	if got != "host=desktop" {
		t.Errorf("got %q", got)
	}
}

func TestRender_missingVarIsError(t *testing.T) {
	h := &manifest.Host{Name: "laptop", Vars: map[string]string{}}
	_, err := Render("{{ .Vars.nope }}", h)
	if err == nil {
		t.Fatal("expected error for missing var")
	}
}
