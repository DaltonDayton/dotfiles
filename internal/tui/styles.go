// Package tui contains the Lipgloss styles, Huh selector, and Bubble Tea
// progress view. The runner never imports this package — tui consumes events.
package tui

import "github.com/charmbracelet/lipgloss"

var (
	Title = lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#7AA2F7"))
	Subtle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("#565F89"))
	Success = lipgloss.NewStyle().Foreground(lipgloss.Color("#9ECE6A"))
	Warn    = lipgloss.NewStyle().Foreground(lipgloss.Color("#E0AF68"))
	Error   = lipgloss.NewStyle().Foreground(lipgloss.Color("#F7768E"))
)
