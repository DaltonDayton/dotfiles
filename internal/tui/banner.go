package tui

import "fmt"

func Banner(hostName, profilePath string) string {
	title := Title.Render("quill")
	line := fmt.Sprintf("%s  %s %s", title, Subtle.Render("detected host:"), Success.Render(hostName))
	return line + "\n" + Subtle.Render("using profile: "+profilePath)
}
