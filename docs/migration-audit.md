# Migration Audit: `~/.dotfiles/` → `quill`

## 1. Scope

| | Original (`~/.dotfiles/arch/modules/`) | New (`/home/dalton/Development/.dotfiles/modules/`) |
|---|---|---|
| Modules | `asdf, claude-code, fonts, gaming, git, hyprland, insync, kitty, misc, neovim, nvidia, obsidian, python, shell, solaar, theme, tmux` | `ai, asdf, fonts, gaming, git, hyprland, neovim, obsidian, python, shell, solaar, tmux` |
| Host manifest | hardcoded in `install.sh` | `hosts/archlinux.toml`, `hosts/archlaptop.toml` |
| Both hosts enable | — | `git, shell, tmux, fonts, asdf, python, neovim, hyprland, ai, obsidian, solaar` |
| Desktop only | — | `gaming` (`hosts/archlinux.toml`) |

---

## 2. Already handled — no action

| Original | Where it landed | Notes |
|---|---|---|
| `claude-code` | `modules/ai/` | settings.json ported; opencode added; node moved to asdf |
| `kitty` | `modules/hyprland/files/kitty/` | merged in |
| `theme` | `modules/hyprland/` (matugen + indirection) | picker scripts `apply-theme.sh`, `theme-switcher.sh`, `wallpaper-picker.sh`, `wallpaper-picker.rasi` all present |
| `arch/install.sh` orchestration | `quill` runner + TUI | logging/errors/summary improved |
| `common.sh` shared bash | — | obsoleted by Go runner |
| asdf node install | `modules/asdf/install.sh` | also adds ruby |
| tmux TPM clone | `modules/tmux/install.sh` | clones + runs `install_plugins` |
| shell chsh | `modules/shell/install.sh` | `sudo chsh -s "$(command -v zsh)"` |

---

## 3. Genuine gaps

### 3a. Load-bearing

All resolved.

**NVIDIA early KMS + suspend** — verified on laptop 2026-05-09: Hyprland starts cleanly and suspend/resume works. Kernel + NVIDIA defaults cover what the original modprobe + mkinitcpio edits used to do. No port needed.

| Piece | Status |
|---|---|
| Laptop NVIDIA packages (`nvidia-open-dkms`, `nvidia-utils`, `nvidia-prime`, `vulkan-tools`) | ✅ ported (hyprland module, `hosts = ["archlaptop"]`) |
| Xorg iGPU drop-in (`/etc/X11/xorg.conf.d/20-nvidia-ignore.conf`) | ✅ ported (`hyprland/install.sh`) |
| `/etc/modprobe.d/nvidia-modeset.conf` (`nvidia_drm.modeset=1`) | ⏭ skipped (defaults sufficient) |
| `mkinitcpio.conf` MODULES early-KMS edit | ⏭ skipped (defaults sufficient) |
| `nvidia-suspend.service` / `nvidia-resume.service` enablement | ⏭ skipped (defaults sufficient) |

**`python` module** — ✅ ported as `modules/python/`.
- `[[packages]] uv` only. `uv python install` was deliberately dropped: uv auto-downloads on demand for `uv venv --python X.Y` / `uv run`, so a pre-installed "global" uv-managed Python adds no value over the Arch system Python for a venv-per-project workflow.
- Zsh completion lives in `modules/shell/files/.zshrc` (live integrations block) as `command -v uv >/dev/null && eval "$(uv generate-shell-completion zsh)"` — guarded so the line is safe even if the python module is later disabled.

### 3b. Nice-to-have

| Gap | Original | Status |
|---|---|---|
| `fc-cache -fv` post-install | `arch/modules/fonts/fonts.sh` | ⏭ skipped — pacman font packages run their own triggers; only revisit if user fonts get symlinked |
| `man-db` package | `arch/modules/git/git.sh` package list | ✅ added to `modules/git/module.toml` |

### 3c. Decide-and-skip-or-port (unported modules)

| Module | Status |
|---|---|
| `insync` | ⏭ dropped — user no longer uses it |
| `gaming` | ✅ ported as `modules/gaming/` (`hosts = ["archlinux"]`) |
| `obsidian` | ✅ ported as `modules/obsidian/` (both hosts) |
| `solaar` | ✅ ported as `modules/solaar/` (both hosts; `install.sh` symlinks the udev rule) |
| `misc` | ⏭ skipped — empty placeholder in original |

### 3d. Out of scope / probably skip

| Item | Reason |
|---|---|
| `other_configs/alacritty.toml` | alacritty not in any host; kitty replaced it |
| `other_configs/improvedtube.json` | browser extension config, not dotfiles concern |
| `scripts/clearnvimcache.sh`, `scripts/list-explicit-packages.sh` | one-off utilities; keep outside `quill` |
| `wsl_ubuntu/` | explicitly out of scope per `CLAUDE.md` |
| `shared_configs/claude/CLAUDE.md.template` | per-project bootstrap template, doesn't belong in the user-level `ai` module |

---

## 4. Remaining work

Migration content-complete as of 2026-05-09. Before merging `startover` → `main`:

- End-to-end verification on both hosts: `./bin/quill apply` clean and idempotent on `archlinux` and `archlaptop`. Smoke-test the new modules interactively (sudo required):
  - `./bin/quill apply solaar`
  - `./bin/quill apply gaming` (archlinux only — heavy install: ~30 pacman packages + AUR build of `faugus-launcher`)
  - `./bin/quill apply obsidian` (already verified idempotent on this machine)
- Fresh-bootstrap sanity check (`bootstrap.sh` → `quill install` flow).
- Decide merge strategy (preserve 144-commit history vs squash to a single rewrite cut-over).
