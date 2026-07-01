package tui

import "github.com/charmbracelet/huh"

// PickProfile asks for OS (default from detected), then Machine when OS=Arch.
// Returns internal os id ("arch"/"ubuntu") and machine ("desktop"/"laptop"/"").
func PickProfile(defaultOS string) (string, string, error) {
	osChoice := defaultOS
	if osChoice != "arch" {
		osChoice = "ubuntu"
	}
	if err := huh.NewSelect[string]().
		Title(Title.Render("Which OS?")).
		Options(
			huh.NewOption("Arch", "arch"),
			huh.NewOption("WSL", "ubuntu"),
		).
		Value(&osChoice).Run(); err != nil {
		return "", "", err
	}
	if osChoice != "arch" {
		return "ubuntu", "", nil
	}
	machine := "desktop"
	if err := huh.NewSelect[string]().
		Title(Title.Render("Desktop or Laptop?")).
		Options(
			huh.NewOption("Desktop", "desktop"),
			huh.NewOption("Laptop", "laptop"),
		).
		Value(&machine).Run(); err != nil {
		return "", "", err
	}
	return "arch", machine, nil
}
