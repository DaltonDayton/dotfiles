package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// ensureAURHelper installs yay from source if missing. Runs as a pre-flight
// step before any module action so declarative AUR packages can trust yay
// is on PATH. Idempotent: skipped silently when yay is already installed.
func ensureAURHelper() error {
	if _, err := exec.LookPath("yay"); err == nil {
		return nil
	}
	fmt.Println("Bootstrapping AUR helper: yay")
	return bootstrapYay()
}

// bootstrapYay clones yay from AUR and builds it via makepkg. Inherits stdio
// so the user can watch makepkg progress — this runs before the TUI takes
// over.
func bootstrapYay() error {
	if err := runInherit("sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"); err != nil {
		return fmt.Errorf("install base-devel: %w", err)
	}

	tmp, err := os.MkdirTemp("", "quill-yay-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)
	repo := filepath.Join(tmp, "yay")
	if err := runInherit("git", "clone", "https://aur.archlinux.org/yay.git", repo); err != nil {
		return fmt.Errorf("clone yay: %w", err)
	}
	cmd := exec.Command("makepkg", "-si", "--noconfirm")
	cmd.Dir = repo
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("makepkg -si: %w", err)
	}
	return nil
}

func runInherit(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
