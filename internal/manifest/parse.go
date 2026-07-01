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

// ParseProfile reads and decodes a profiles/<name>.toml file.
func ParseProfile(path string) (*Profile, error) {
	var p Profile
	if _, err := toml.DecodeFile(path, &p); err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	if p.Name == "" {
		return nil, fmt.Errorf("%s: profile is missing required field 'name'", path)
	}
	if p.Vars == nil {
		p.Vars = map[string]string{}
	}
	return &p, nil
}
