// Package manifest defines the on-disk TOML schema for modules and host
// profiles, plus parsers that decode them.
package manifest

// Module mirrors modules/<name>/module.toml.
type Module struct {
	Name        string   `toml:"name"`
	Description string   `toml:"description"`
	Tags        []string `toml:"tags"`
	DependsOn   []string `toml:"depends_on"`
	Hosts       []string `toml:"hosts"`
	OS          []string `toml:"os"`
	Machine     []string `toml:"machine"`

	Packages    []Packages  `toml:"packages"`
	Symlinks    []Symlink   `toml:"symlinks"`
	Commands    []Command   `toml:"commands"`
	Files       []File      `toml:"files"`
	Services    []Service   `toml:"services"`
	Directories []Directory `toml:"directories"`
	Todos       []Todo      `toml:"todos"`
}

type Packages struct {
	// Manager is "pacman" | "aur" | "yay" | "flatpak" | "apt". Optional — empty
	// defaults to "yay", which handles both official repos and AUR. Use
	// "pacman" to force official-repo-only (faster, no AUR network round
	// trip), or "aur" to flag AUR-sourced packages explicitly. "aur" is a
	// logical alias that resolves to yay.
	// Manager implies the target OS (pacman/yay/aur → Arch, apt → Ubuntu,
	// flatpak → any), so the os[] field is rarely needed on a packages block.
	Manager string   `toml:"manager"`
	Names   []string `toml:"names"`
	Hosts   []string `toml:"hosts"`
	OS      []string `toml:"os"`
}

type Symlink struct {
	Src   string   `toml:"src"`
	Dst   string   `toml:"dst"`
	Hosts []string `toml:"hosts"`
	OS    []string `toml:"os"`
}

type Command struct {
	Run   string   `toml:"run"`
	Check string   `toml:"check"`
	Hosts []string `toml:"hosts"`
	OS    []string `toml:"os"`
}

type File struct {
	Dst         string   `toml:"dst"`
	Content     string   `toml:"content"`
	ContentFrom string   `toml:"content_from"`
	Mode        string   `toml:"mode"`
	Hosts       []string `toml:"hosts"`
	OS          []string `toml:"os"`
}

type Service struct {
	Name  string   `toml:"name"`
	Scope string   `toml:"scope"` // "user" | "system"
	State string   `toml:"state"` // "enabled" | "started" | "enabled+started"
	Hosts []string `toml:"hosts"`
	OS    []string `toml:"os"`
}

type Directory struct {
	Path  string   `toml:"path"`
	Mode  string   `toml:"mode"`
	Hosts []string `toml:"hosts"`
	OS    []string `toml:"os"`
}

// Todo is a manual follow-up step printed after a run when its Check fails.
// It does not mutate the system — actions and install.sh do that.
type Todo struct {
	Message string `toml:"message"`
	Check   string `toml:"check"` // shell cmd; exit 0 = done. Empty = always shown.
}

// Profile mirrors profiles/<name>.toml — the OS/machine combo the user picks.
type Profile struct {
	Name    string            `toml:"name"`
	OS      string            `toml:"os"`      // "arch" | "ubuntu"
	Machine string            `toml:"machine"` // "desktop" | "laptop" | "" (WSL)
	Modules []string          `toml:"modules"`
	Vars    map[string]string `toml:"vars"`
}
