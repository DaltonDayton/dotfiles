package tui

import (
	"fmt"
	"sort"

	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/charmbracelet/huh"
)

// SelectModules renders one flat multi-select over mods (already filtered to
// the profile's valid set by the caller). Names in preselected start checked.
func SelectModules(mods []*module.Module, preselected map[string]bool) ([]string, error) {
	sorted := make([]*module.Module, len(mods))
	copy(sorted, mods)
	sort.Slice(sorted, func(i, j int) bool {
		pi, pj := preselected[sorted[i].Name], preselected[sorted[j].Name]
		if pi != pj {
			return pi // preselected (defaults) first
		}
		return sorted[i].Name < sorted[j].Name
	})

	var options []huh.Option[string]
	chosen := []string{}
	for _, m := range sorted {
		label := m.Name
		if m.Description != "" {
			label = fmt.Sprintf("%s — %s", m.Name, m.Description)
		}
		options = append(options, huh.NewOption(label, m.Name))
		if preselected[m.Name] {
			chosen = append(chosen, m.Name)
		}
	}

	field := huh.NewMultiSelect[string]().
		Title(Title.Render("Modules")).
		Options(options...).
		Value(&chosen)
	if err := huh.NewForm(huh.NewGroup(field)).Run(); err != nil {
		return nil, err
	}
	return unique(chosen), nil
}

func unique(xs []string) []string {
	seen := map[string]bool{}
	out := xs[:0]
	for _, x := range xs {
		if !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}
