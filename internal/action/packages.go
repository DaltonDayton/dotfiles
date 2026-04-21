package action

import (
	"fmt"
	"os/exec"
	"strings"
)

// PackageDriver is the shape every package manager implements. Adding a new
// manager (e.g., apt, brew) is a matter of implementing these two methods
// and registering the driver in pkgDrivers below.
type PackageDriver interface {
	IsInstalled(name string) (bool, error)
	Install(names []string) error
}

// pkgDrivers is overridable for tests — swap in fakes to avoid real package
// manager calls.
var pkgDrivers = map[string]PackageDriver{
	"pacman":  &pacmanDriver{},
	"paru":    &paruDriver{},
	"yay":     &yayDriver{},
	"flatpak": &flatpakDriver{},
}

// Packages installs a list of packages using the named manager. Idempotent:
// Check returns true iff every name is already installed.
type Packages struct {
	Manager string
	Names   []string
}

func (p *Packages) Describe() string {
	return fmt.Sprintf("%s: install %s", p.Manager, strings.Join(p.Names, ", "))
}

func (p *Packages) driver() (PackageDriver, error) {
	d, ok := pkgDrivers[p.Manager]
	if !ok {
		return nil, fmt.Errorf("unknown package manager %q", p.Manager)
	}
	return d, nil
}

func (p *Packages) Check() (bool, error) {
	d, err := p.driver()
	if err != nil {
		return false, err
	}
	for _, n := range p.Names {
		ok, err := d.IsInstalled(n)
		if err != nil {
			return false, err
		}
		if !ok {
			return false, nil
		}
	}
	return true, nil
}

func (p *Packages) Apply() error {
	d, err := p.driver()
	if err != nil {
		return err
	}
	var missing []string
	for _, n := range p.Names {
		ok, err := d.IsInstalled(n)
		if err != nil {
			return err
		}
		if !ok {
			missing = append(missing, n)
		}
	}
	if len(missing) == 0 {
		return nil
	}
	return d.Install(missing)
}

// --- drivers -----------------------------------------------------

type pacmanDriver struct{}

func (pacmanDriver) IsInstalled(name string) (bool, error) {
	err := exec.Command("pacman", "-Q", name).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, err
}

func (pacmanDriver) Install(names []string) error {
	args := append([]string{"pacman", "-S", "--needed", "--noconfirm"}, names...)
	return runSudo(args...)
}

type paruDriver struct{}

func (paruDriver) IsInstalled(name string) (bool, error) {
	return pacmanDriver{}.IsInstalled(name) // paru reads the pacman DB
}
func (paruDriver) Install(names []string) error {
	args := append([]string{"-S", "--needed", "--noconfirm"}, names...)
	return exec.Command("paru", args...).Run()
}

type yayDriver struct{}

func (yayDriver) IsInstalled(name string) (bool, error) {
	return pacmanDriver{}.IsInstalled(name)
}
func (yayDriver) Install(names []string) error {
	args := append([]string{"-S", "--needed", "--noconfirm"}, names...)
	return exec.Command("yay", args...).Run()
}

type flatpakDriver struct{}

func (flatpakDriver) IsInstalled(name string) (bool, error) {
	err := exec.Command("flatpak", "info", name).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, err
}
func (flatpakDriver) Install(names []string) error {
	args := append([]string{"install", "-y"}, names...)
	return exec.Command("flatpak", args...).Run()
}

// runSudo uses sudo -n so a missing cached credential errors out instead of
// blocking on a password prompt. Users are expected to `sudo -v` before
// running quill apply.
func runSudo(args ...string) error {
	full := append([]string{"-n", "--"}, args...)
	out, err := exec.Command("sudo", full...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("sudo %s: %w (%s)", strings.Join(args, " "), err, string(out))
	}
	return nil
}
