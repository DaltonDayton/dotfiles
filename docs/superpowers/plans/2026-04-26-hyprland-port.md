# Hyprland config port: `main` → `startover`

> Working document. Update the **Status** column as chunks land. When all chunks are done and idempotency holds end-to-end, merge `startover` → `main`.

## Context

The repo is mid-rewrite. `main` holds the **old monolithic dotfiles** (`arch/modules/hyprland/`, hand-rolled Jinja2 theming via `arch/modules/theme/switch.py`). `startover` is the **new quill module layout** (`modules/hyprland/files/...`) with a matugen-driven theming engine — already substantial (91 commits, 156 files), but several pieces from the old config were intentionally deferred per the spec.

A worktree at `/home/dalton/.dotfiles-main` exposes the old layout side-by-side without flipping branches. Active edits happen in `/home/dalton/.dotfiles` on `startover`. When `startover` is in a good spot, merge it back to `main`.

**Approach:** fine-grained chunks (smaller than per-app), review-and-rewrite per chunk (treat the old files as reference, not a verbatim source). One commit per chunk; idempotency check between chunks.

## Source / target reference

- **Source root:** `/home/dalton/.dotfiles-main/arch/modules/hyprland/`
- **Target root:** `/home/dalton/.dotfiles/modules/hyprland/`
- **Spec to keep in sync if scope changes:** [`docs/superpowers/specs/2026-04-25-hyprland-module-design.md`](../specs/2026-04-25-hyprland-module-design.md) — the "Deferred" list mentions voxtype, sddm-theme, sddm.conf, device-keyed monitors. Drop items from "Deferred" as they're ported.
- **`module.toml` to update as new actions are added:** `modules/hyprland/module.toml`

## What to skip outright (do NOT port)

Obsolete under the new architecture:

- `arch/modules/theme/switch.py` (586 lines, Jinja2 engine) → replaced by matugen + `files/hypr/scripts/apply-theme.sh`
- `arch/modules/theme/palettes/*.toml`, `templates/**/*.j2` → replaced by `files/matugen/templates/` and `files/themes/<name>/`
- `arch/modules/theme/wallpapers/` → wallpapers already reorganized under `files/themes/<name>/wallpapers/` and `files/wallpapers/`
- Old `hyprland.sh` (376-line bootstrap) → replaced by `module.toml` + `install.sh`
- `arch/modules/hyprland/swaync/` (just symlinks to generated output) → target's swaync setup supersedes it
- `arch/modules/hyprland/waybar/mocha.css` → target has 6 layout presets; the catppuccin-mocha-specific stylesheet doesn't fit the matugen flow

## Chunks

| # | Chunk | Status | Commit |
|---|---|---|---|
| 1 | `ocr-screenshot.sh` | ☑ done | `5a506f5` (bundled w/ aur cleanup) |
| 2 | `songdetail.sh` | ☒ skipped | dead code: 0 callers, superseded by `mediaplayer.py` |
| 3 | Extract `keybindings.conf` from `hyprland.conf` | ☑ done | `10d3092` |
| 3.5 | Extract `programs.conf` from `hyprland.conf` | ☑ done | `94963c4` (added beyond original plan) |
| 4 | Extract `windowrules.conf` from `hyprland.conf` | ☑ done | `e4f9139` |
| 5 | Add `hypridle.conf` | ☑ done | `e4f9139` (file + `hypridle` pkg + `exec-once`) |
| 6 | Device-keyed monitor variants | ☑ done | hostname-keyed (archlinux/archlaptop/default), `link_device_variant` in install.sh |
| 7 | Bibata cursor theme bundle | ☑ done via AUR | `bibata-cursor-theme-bin` pkg + env vars; no bundled `files/cursors/` |
| 8 | voxtype configs | ☑ done | hostname-keyed; `voxtype` AUR + `wtype` pacman; setup block in install.sh |
| 9 | `voxtype-clipboard.sh` | ☑ done | tracked at `files/hypr/scripts/voxtype-clipboard.sh` |
| 10 | voxtype submap (`hypr/conf.d/voxtype-submap.conf`) | ☑ done | submap tracked in repo (not generated); sourced from `hyprland.conf` |
| 11 | `sddm.conf` | ☑ done | sudo symlink to `/etc/sddm.conf`; theme dir renamed to `quill` |
| 12 | `xorg-laptop.conf` | ☑ done | host-keyed (`files/xorg/archlaptop.conf`), sudo-symlinked to `/etc/X11/xorg.conf.d/20-nvidia-ignore.conf` |
| 13 | SDDM theme bundle | ☑ done | `files/sddm-theme/`, sudo cp -rT to `/usr/share/sddm/themes/quill/`; host-keyed `theme.archlaptop.conf` overrides |
| 14 | hyprlock config | ☑ done | reuses hypr's color vars (no separate matugen template); active wallpaper via state symlink |

Order is dependencies-first, smallest-blast-radius-first. Easy to reorder.

---

### Tier 1 — small scripts (warm-up; validates the workflow)

**1. `ocr-screenshot.sh`** (33 lines)
- Source: `arch/modules/hyprland/hypr/Scripts/ocr-screenshot.sh`
- Target: `modules/hyprland/files/hypr/scripts/ocr-screenshot.sh` (note: target uses lowercase `scripts/`)
- Review: confirm the screenshot tool it calls (`grim`/`grimblast`) is in `module.toml` packages; if not, add it. Add a symlink action for the script if not auto-symlinked via the `hypr/` dir.

**2. `songdetail.sh`** (5 lines)
- Source: `arch/modules/hyprland/hypr/Scripts/songdetail.sh`
- Target: `modules/hyprland/files/hypr/scripts/songdetail.sh`
- Review: tiny; just confirm it's still useful (waybar `mediaplayer.py` may already cover this).

### Tier 2 — refactor target's `hyprland.conf` into pieces

Treat `arch/modules/hyprland/hypr/` as the source of truth for Hyprland behavior. The seed content copied from `~/.config/hypr_new/` / `startover` was only a scaffold and must not win if it conflicts with the working `arch/` config.

**3. Extract `keybindings.conf`** (~259 source lines as reference)
- Use `arch/modules/hyprland/hypr/keybindings.conf` as the baseline, not the default `startover` file.
- Port the full working bind set into `files/hypr/keybindings.conf`, then apply only the intentional deltas required by the new module shape:
  - keep `Super+D` and `Super+Shift+D` pointing at `~/.config/hypr/scripts/{theme-switcher,wallpaper-picker}.sh`
  - update legacy `Scripts/` paths to lowercase `scripts/`
  - leave voxtype-related binds deferred until the voxtype config/scripts/submap land
- Source the new file via `source = ./keybindings.conf` only after any variables it uses (`$terminal`, `$fileManager`, `$menu`) are defined.

**4. Extract `windowrules.conf`** (~106 source lines as reference)
- Port `arch/modules/hyprland/hypr/windowrules.conf` directly into `files/hypr/windowrules.conf` and source it from the parent config.

**5. Add `hypridle.conf`** (29 source lines)
- New file `files/hypr/hypridle.conf`, copied from the working `arch` setup and then adapted only if the new module shape requires it. Add `hypridle` package to `module.toml` and an `exec-once = hypridle` line in `hyprland.conf` (it's a user-session daemon, not a systemd service).

### Tier 3 — device-keyed monitor variants

**6. Monitor presets** (source: `hypr/monitors/{default,desktop,laptop}.conf`)
- Target currently has a single `files/hypr/monitors.conf` (22 lines). Spec listed device-keyed variants as deferred.
- Approach options: (a) convert `monitors.conf` into a templated `monitors.conf.tmpl` keyed off host vars, OR (b) add `files/hypr/monitors/<host>.conf` and select via host manifest. Pick one and document the choice in the spec.

### Tier 4 — Bibata cursor theme

**7. Bibata-Cursors bundle** (186 binary files, 3 variants)
- Source: `arch/modules/hyprland/Bibata-Cursors/Bibata-Modern-{Amber,Classic,Ice}/`
- Target: `modules/hyprland/files/cursors/Bibata-Modern-*/` (or skip the bundled files and depend on the AUR package — discuss before doing).
- Add a symlink action that lands them under `~/.local/share/icons/`, plus the `hyprcursor` env vars in `hyprland.conf` if not already set.

### Tier 5 — voxtype (speech-to-text)

Three pieces, port together (they only make sense as a set):

**8. voxtype configs** — `arch/modules/hyprland/voxtype/configs/{default,laptop}.toml` → `modules/hyprland/files/voxtype/{default,laptop}.toml`. Add `voxtype` package (likely AUR — confirm in `module.toml`).

**9. `voxtype-clipboard.sh`** — `hypr/Scripts/voxtype-clipboard.sh` → `files/hypr/scripts/voxtype-clipboard.sh`.

**10. voxtype submap** — `hypr/conf.d/voxtype-submap.conf` (36 lines) → `files/hypr/conf.d/voxtype-submap.conf`. Source it from `hyprland.conf`. Update spec (drop voxtype from "Deferred").

### Tier 6 — SDDM (login screen)

**11. `sddm.conf`** (2 lines) — `arch/modules/hyprland/config/sddm.conf` → likely a `[[files]]` action writing to `/etc/sddm.conf.d/quill.conf` (sudo). Add `sddm` package + service.

**12. `xorg-laptop.conf`** (13 lines) — `arch/modules/hyprland/config/xorg-laptop.conf` → host-specific X11 fallback. Skip if committed to Wayland-only on the laptop; otherwise add as a host-keyed `[[files]]` action.

**13. SDDM theme bundle** (31 files: Main.qml, Components/, assets/, icons/, backgrounds/, theme.conf, theme.laptop.conf)
- Source: `arch/modules/hyprland/sddm-theme/`
- Target: `modules/hyprland/files/sddm-theme/` plus a symlink action to `/usr/share/sddm/themes/quill/` (sudo).
- Review: `theme.conf` references absolute paths and a wallpaper — confirm both still resolve. Update spec (drop sddm-theme from "Deferred").

### Tier 7 — hyprlock (lock screen)

**14. hyprlock config + matugen template**
- Source: `arch/modules/theme/templates/hyprlock/hyprlock.conf.j2` (100 lines) — read it to extract the structure, but rewrite as:
  - `files/hyprlock/hyprlock.conf` (static layout, sources colors)
  - `files/matugen/templates/hyprlock-colors.conf` (matugen-rendered colors)
  - `files/hyprlock/colors/colors.conf` indirection file (matches the pattern used by hypr/kitty/waybar)
- Add `hyprlock` package, `exec-once = hyprlock` from `hyprland.conf` (or wire via hypridle's `lock_cmd`). Update `matugen/config.toml` to emit the new template.

---

## Per-chunk verification

After each commit on `startover`:

```bash
go test ./...                             # core invariants still hold
go build -o ./bin/quill ./cmd/quill
./bin/quill apply hyprland                # apply the chunk
./bin/quill apply hyprland                # rerun — must be a no-op (idempotency)
```

For chunks that touch `hyprland.conf` or `keybindings.conf`: `hyprctl reload` and verify no parse errors with `journalctl --user -u hyprland -n 50` (or check `~/.local/share/hyprland/hyprland.log`).

For Tier 6 SDDM chunks: don't reboot until both `sddm.conf` and the theme are in place; verify with `sddm --test-mode` if available, or in a VM.

## Critical files to read before each chunk

- Always: `modules/hyprland/module.toml` (to know what actions already exist)
- Tier 2: `modules/hyprland/files/hypr/hyprland.conf` (to know what to extract)
- Tier 3: `modules/hyprland/files/hypr/monitors.conf` + `hosts/<hostname>.toml`
- Tier 4–7: `internal/manifest/schema.go` (to confirm action types like `[[files]]` with `dest` outside `$HOME` need anything special, e.g. sudo)

## Merge-back

Once all chunks land and idempotency holds end-to-end:

```bash
cd /home/dalton/.dotfiles-main
git merge startover
git push
git worktree remove /home/dalton/.dotfiles-main   # tear down the worktree
```

---

## Post-port follow-ups (landed after the table above)

These shipped after chunk 14 and aren't part of the original port, but are worth recording:

- **Voxtype end-to-end on `archlaptop`** (commit `9836354`):
  - `link_device_variant` generalized to take a file extension; voxtype now picks `archlaptop.toml` instead of falling through to a stale upstream `default.conf`.
  - Host-scoped pacman packages introduced: `sof-firmware` (rt715 SoundWire mic — silent without it), `linux-headers` (DKMS prereq), `nvidia-open-dkms` + `nvidia-utils` + `nvidia-prime` (proprietary NVIDIA stack so whisper's Vulkan backend targets the dGPU instead of nouveau), `vulkan-tools`.
  - Tracked systemd drop-in (`files/voxtype/systemd/<host>.conf`) symlinked into `~/.config/systemd/user/voxtype.service.d/gpu.conf` by `install.sh`; daemon-reload + restart only when the link target changes.
  - Voxtype config pinned to Vulkan device index 1 via `gpu_device` (the string-based `VOXTYPE_VULKAN_DEVICE=nvidia` filter wasn't honored on this rig).
  - Idempotency fix: `voxtype setup gpu --enable` is now guarded on current status (the previous `grep -q` pattern triggered SIGPIPE under `set -o pipefail`, inverting the guard).
  - Cold-start transcription ~8s (model load to GPU); warm runs ~0.7s.
