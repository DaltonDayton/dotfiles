package action

import "testing"

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
		"paru":    true,
		"yay":     true,
		"flatpak": false,
		"unknown": false,
	}
	for mgr, want := range cases {
		p := &Packages{Manager: mgr}
		if got := p.NeedsSudo(); got != want {
			t.Errorf("NeedsSudo(%q) = %v, want %v", mgr, got, want)
		}
	}
}
