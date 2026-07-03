# Migration Audit: `~/.dotfiles/` → `quill`

## 1. Scope

| | Original (`~/.dotfiles/arch/modules/`) | New (`modules/`) |
|---|---|---|
| Modules | `asdf, claude-code, fonts, gaming, git, hyprland, insync, kitty, misc, neovim, nvidia, obsidian, python, shell, solaar, theme, tmux` | `ai, asdf, fonts, gaming, git, hyprland, neovim, obsidian, python, razer, shell, solaar, tmux, windows-terminal` |
| Profile manifest | hardcoded in `install.sh` | `profiles/arch-desktop.toml`, `profiles/arch-laptop.toml`, `profiles/wsl.toml` |
| All Arch profiles enable | — | `git, shell, tmux, fonts, asdf, python, neovim, hyprland, ai, obsidian, solaar` |
| Desktop only | — | `gaming, razer` (`profiles/arch-desktop.toml`) |
| WSL (`profiles/wsl.toml`) enables | — | `git, shell, tmux, neovim, ai, python, asdf, windows-terminal` (os-gated to `ubuntu`) |

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
| Laptop NVIDIA packages (`nvidia-open-dkms`, `nvidia-utils`, `nvidia-prime`, `vulkan-tools`) | ✅ ported (hyprland module, `hosts = ["arch-laptop"]`) |
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
| `gaming` | ✅ ported as `modules/gaming/` (`os = ["arch"]`, `machine = ["desktop"]`) |
| `obsidian` | ✅ ported as `modules/obsidian/` (both hosts) |
| `solaar` | ✅ ported as `modules/solaar/` (both hosts; `install.sh` symlinks the udev rule) |
| `misc` | ⏭ skipped — empty placeholder in original |

### 3d. Out of scope / probably skip

| Item | Reason |
|---|---|
| `other_configs/alacritty.toml` | alacritty not in any host; kitty replaced it |
| `other_configs/improvedtube.json` | browser extension config, not dotfiles concern |
| `scripts/clearnvimcache.sh`, `scripts/list-explicit-packages.sh` | one-off utilities; keep outside `quill` |
| `wsl_ubuntu/` | ✅ ported — WSL is now in-scope. Old split `arch/` + `wsl_ubuntu/` trees collapsed into unified os-gated modules; WSL uses `profiles/wsl.toml` (git, shell, tmux, neovim, ai, python, asdf, windows-terminal). Single config source, no cross-OS drift. |
| `shared_configs/claude/CLAUDE.md.template` | per-project bootstrap template, doesn't belong in the user-level `ai` module |

---

## 4. Remaining work

Migration content-complete. WSL/Ubuntu support and the OS/machine profile picker landed after the original audit; both are ported and verified.

- ✅ End-to-end verification: `quill apply` clean and idempotent on arch-desktop, arch-laptop, and WSL (confirmed 2026-07-01).
- ✅ Build + `go test ./...` green.
- Merge strategy: preserve history via fast-forward (linear), cut over `startover` → `main`.
