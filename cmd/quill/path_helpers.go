package main

import (
	"bufio"
	"bytes"
	"os"
	"strings"
)

const pathExport = `export PATH="$HOME/.local/bin:$PATH"`

// ensurePathLine appends pathExport to rcPath if no existing line already adds
// ~/.local/bin to PATH. Returns true if the file was modified.
func ensurePathLine(rcPath string) (bool, error) {
	data, err := os.ReadFile(rcPath)
	if os.IsNotExist(err) {
		data = nil
	} else if err != nil {
		return false, err
	}
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, ".local/bin") && strings.Contains(line, "PATH") && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			return false, nil
		}
	}
	if len(data) > 0 && data[len(data)-1] != '\n' {
		data = append(data, '\n')
	}
	data = append(data, []byte("\n# Added by quill\n"+pathExport+"\n")...)
	return true, os.WriteFile(rcPath, data, 0o644)
}
