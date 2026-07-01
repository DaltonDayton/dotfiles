package module

// ValidFor reports whether a module may be installed under the picked profile.
// os empty on the module = any OS; machine empty = any machine. When the pick's
// machine is "" (WSL), the machine axis is not applied.
func ValidFor(m *Module, osName, machine string) bool {
	if !listAllows(m.OS, osName) {
		return false
	}
	if machine != "" && !listAllows(m.Machine, machine) {
		return false
	}
	return true
}

// listAllows returns true if list is empty (any) or contains want.
func listAllows(list []string, want string) bool {
	if len(list) == 0 {
		return true
	}
	for _, v := range list {
		if v == want {
			return true
		}
	}
	return false
}

func FilterValid(mods []*Module, osName, machine string) []*Module {
	var out []*Module
	for _, m := range mods {
		if ValidFor(m, osName, machine) {
			out = append(out, m)
		}
	}
	return out
}

// Preselect returns which of candidates are present in valid (checked-by-default
// set), silently dropping candidates that are not valid for the profile.
func Preselect(valid []*Module, candidates []string) map[string]bool {
	validSet := map[string]bool{}
	for _, m := range valid {
		validSet[m.Name] = true
	}
	out := map[string]bool{}
	for _, name := range candidates {
		if validSet[name] {
			out[name] = true
		}
	}
	return out
}
