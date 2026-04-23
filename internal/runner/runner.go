// Package runner orchestrates dependency resolution, host filtering,
// action construction, and the apply loop.
package runner

import (
	"fmt"

	"github.com/DaltonDayton/dotfiles/internal/module"
)

// ResolveDeps returns the transitive closure of selected modules in
// topological (dependency-first) order. Errors on unknown names or cycles.
//
// aurHelper is the host's chosen AUR helper ("paru" or "yay"); the name
// "aur" used in a module's depends_on or in the selected list is rewritten
// to it so modules can declare "needs an AUR helper" without hard-coding
// one. Pass "" when no AUR helper is configured — an "aur" reference in
// that case will error.
func ResolveDeps(all []*module.Module, selected []string, aurHelper string) ([]*module.Module, error) {
	byName := map[string]*module.Module{}
	for _, m := range all {
		byName[m.Name] = m
	}
	resolve := func(name string) (string, error) {
		if name != "aur" {
			return name, nil
		}
		if aurHelper == "" {
			return "", fmt.Errorf("module references \"aur\" but host has no aur_helper set")
		}
		return aurHelper, nil
	}

	var order []*module.Module
	visited := map[string]bool{}
	onStack := map[string]bool{}

	var visit func(name string) error
	visit = func(name string) error {
		name, err := resolve(name)
		if err != nil {
			return err
		}
		if visited[name] {
			return nil
		}
		if onStack[name] {
			return fmt.Errorf("dependency cycle involving %q", name)
		}
		m, ok := byName[name]
		if !ok {
			return fmt.Errorf("unknown module %q", name)
		}
		onStack[name] = true
		for _, dep := range m.DependsOn {
			if err := visit(dep); err != nil {
				return err
			}
		}
		onStack[name] = false
		visited[name] = true
		order = append(order, m)
		return nil
	}
	for _, name := range selected {
		if err := visit(name); err != nil {
			return nil, err
		}
	}
	return order, nil
}

// FilterByHost drops modules whose Hosts list excludes hostName. An empty
// Hosts list means "any host".
func FilterByHost(mods []*module.Module, hostName string) []*module.Module {
	var kept []*module.Module
	for _, m := range mods {
		if len(m.Hosts) == 0 {
			kept = append(kept, m)
			continue
		}
		for _, h := range m.Hosts {
			if h == hostName {
				kept = append(kept, m)
				break
			}
		}
	}
	return kept
}
