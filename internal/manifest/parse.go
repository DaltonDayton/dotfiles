package manifest

import (
	"fmt"

	"github.com/BurntSushi/toml"
)

// ParseModule reads and decodes a module.toml file.
func ParseModule(path string) (*Module, error) {
	var m Module
	if _, err := toml.DecodeFile(path, &m); err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	if m.Name == "" {
		return nil, fmt.Errorf("%s: module is missing required field 'name'", path)
	}
	return &m, nil
}

// ParseHost reads and decodes a hosts/<name>.toml file.
func ParseHost(path string) (*Host, error) {
	var h Host
	if _, err := toml.DecodeFile(path, &h); err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	if h.Name == "" {
		return nil, fmt.Errorf("%s: host is missing required field 'name'", path)
	}
	if h.Vars == nil {
		h.Vars = map[string]string{}
	}
	return &h, nil
}
