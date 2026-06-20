package action

import (
	"strings"
	"testing"
)

type fakeDriver struct {
	installed     map[string]bool
	installedHist []string
}

func (d *fakeDriver) IsInstalled(name string) (bool, error) {
	return d.installed[name], nil
}

func (d *fakeDriver) Install(names []string) error {
	for _, n := range names {
		d.installedHist = append(d.installedHist, n)
		if d.installed == nil {
			d.installed = map[string]bool{}
		}
		d.installed[n] = true
	}
	return nil
}

func withPkgDrivers(t *testing.T, drivers map[string]PackageDriver) {
	t.Helper()
	orig := pkgDrivers
	pkgDrivers = drivers
	t.Cleanup(func() { pkgDrivers = orig })
}

func TestPackages_checkAllInstalled(t *testing.T) {
	d := &fakeDriver{installed: map[string]bool{"git": true, "zsh": true}}
	withPkgDrivers(t, map[string]PackageDriver{"pacman": d})

	p := &Packages{Manager: "pacman", Names: []string{"git", "zsh"}}
	ok, err := p.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("expected Check=true when all installed")
	}
}

func TestPackages_applyInstallsMissingOnly(t *testing.T) {
	d := &fakeDriver{installed: map[string]bool{"git": true}}
	withPkgDrivers(t, map[string]PackageDriver{"pacman": d})

	p := &Packages{Manager: "pacman", Names: []string{"git", "zsh"}}
	if err := p.Apply(); err != nil {
		t.Fatal(err)
	}
	if len(d.installedHist) != 1 || d.installedHist[0] != "zsh" {
		t.Errorf("installed history = %v, want [zsh]", d.installedHist)
	}
}

func TestPackages_unknownManager(t *testing.T) {
	withPkgDrivers(t, map[string]PackageDriver{})
	p := &Packages{Manager: "nope", Names: []string{"x"}}
	_, err := p.Check()
	if err == nil {
		t.Fatal("expected error for unknown manager")
	}
}

func TestPackages_satisfiesActionInterface(t *testing.T) {
	var _ Action = (*Packages)(nil)
}

func TestPackages_NeedsSudo(t *testing.T) {
	cases := map[string]bool{
		"pacman":  true,
		"yay":     true,
		"flatpak": false,
		"unknown": false,
		"apt":     true,
	}
	for mgr, want := range cases {
		p := &Packages{Manager: mgr}
		if got := p.NeedsSudo(); got != want {
			t.Errorf("NeedsSudo(%q) = %v, want %v", mgr, got, want)
		}
	}
}

func TestAptDriverRegistered(t *testing.T) {
	if _, ok := pkgDrivers["apt"]; !ok {
		t.Fatal(`pkgDrivers missing "apt"`)
	}
}

// apt-get install is atomic and fails the whole batch on a single 404, which
// happens when the local index is stale (Ubuntu rotated a package version).
// Install must refresh the index first.
func TestAptDriver_InstallRefreshesIndexFirst(t *testing.T) {
	var calls [][]string
	orig := runSudo
	runSudo = func(args ...string) error {
		calls = append(calls, args)
		return nil
	}
	t.Cleanup(func() { runSudo = orig })

	if err := (aptDriver{}).Install([]string{"foo", "bar"}); err != nil {
		t.Fatal(err)
	}
	if len(calls) != 2 {
		t.Fatalf("expected 2 sudo calls (update then install), got %d: %v", len(calls), calls)
	}
	if got := strings.Join(calls[0], " "); got != "apt-get update" {
		t.Errorf("first call = %q, want \"apt-get update\"", got)
	}
	if got := strings.Join(calls[1], " "); got != "apt-get install -y foo bar" {
		t.Errorf("second call = %q, want \"apt-get install -y foo bar\"", got)
	}
}
