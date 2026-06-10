package host

import (
	"bufio"
	"os"
	"strings"
)

// DetectOS returns a normalized OS id for the current machine: "arch",
// "ubuntu", or the raw /etc/os-release ID for anything else ("unknown" if
// the file is missing/empty). Detection is runtime-only — host profiles
// declare nothing about the OS, mirroring how the package manager is already
// abstracted per-action.
func DetectOS() string {
	return detectOSFromFile("/etc/os-release")
}

// detectOSFromFile is the testable core. ID wins; if ID is not one we
// recognize, ID_LIKE is consulted so close relatives (e.g. Pop!_OS reporting
// ID_LIKE="ubuntu debian") still resolve to "ubuntu".
func detectOSFromFile(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return "unknown"
	}
	defer f.Close()

	var id, idLike string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		switch {
		case strings.HasPrefix(line, "ID="):
			id = unquote(strings.TrimPrefix(line, "ID="))
		case strings.HasPrefix(line, "ID_LIKE="):
			idLike = unquote(strings.TrimPrefix(line, "ID_LIKE="))
		}
	}

	switch id {
	case "arch", "ubuntu":
		return id
	}
	for _, like := range strings.Fields(idLike) {
		if like == "ubuntu" || like == "debian" {
			// debian-family distros use apt — quill's "ubuntu" package codepath.
			return "ubuntu"
		}
		if like == "arch" {
			return "arch"
		}
	}
	if id == "" {
		return "unknown"
	}
	return id
}

func unquote(s string) string {
	return strings.Trim(strings.TrimSpace(s), `"'`)
}
