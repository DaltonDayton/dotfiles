package tui

import (
	"fmt"
	"sort"

	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/charmbracelet/huh"
)

// GroupByTag buckets modules by their first tag ("uncategorized" if none).
func GroupByTag(mods []*module.Module) map[string][]*module.Module {
	out := map[string][]*module.Module{}
	for _, m := range mods {
		tag := "uncategorized"
		if len(m.Tags) > 0 {
			tag = m.Tags[0]
		}
		out[tag] = append(out[tag], m)
	}
	return out
}

// SelectModules renders a multi-select grouped by tag. Names in preselected
// are checked by default. Returns names chosen by the user.
func SelectModules(mods []*module.Module, preselected map[string]bool) ([]string, error) {
	groups := GroupByTag(mods)
	tags := make([]string, 0, len(groups))
	for t := range groups {
		tags = append(tags, t)
	}
	sort.Strings(tags)

	var chosen []string
	for _, n := range preselectedOrdered(mods, preselected) {
		chosen = append(chosen, n)
	}

	var fields []huh.Field
	for _, tag := range tags {
		items := groups[tag]
		sort.Slice(items, func(i, j int) bool { return items[i].Name < items[j].Name })
		var options []huh.Option[string]
		for _, m := range items {
			label := m.Name
			if m.Description != "" {
				label = fmt.Sprintf("%s — %s", m.Name, m.Description)
			}
			options = append(options, huh.NewOption(label, m.Name))
		}
		fields = append(fields, huh.NewMultiSelect[string]().
			Title(Title.Render(tag)).
			Options(options...).
			Value(&chosen))
	}
	form := huh.NewForm(huh.NewGroup(fields...))
	if err := form.Run(); err != nil {
		return nil, err
	}
	return unique(chosen), nil
}

func preselectedOrdered(mods []*module.Module, pre map[string]bool) []string {
	var out []string
	for _, m := range mods {
		if pre[m.Name] {
			out = append(out, m.Name)
		}
	}
	return out
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
