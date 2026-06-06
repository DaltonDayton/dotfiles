# Wallpaper manifest design

Date: 2026-06-06
Status: approved

## Problem

Wallpapers live in eleven per-theme directories (`modules/hyprland/files/themes/<name>/wallpapers/`), 132 images, 548M. A wallpaper shared by N themes exists as N physical copies (24 images duplicated today). Management is scattered: adding a wallpaper means choosing directories, and nothing shows what is assigned where. The matugen-mode picker sha256-hashes the entire pool on every open just to collapse those duplicates.

Goals, in priority order: eliminate duplicate copies, give one place to see and edit assignments, make the matugen picker fast. Repo size is explicitly not a goal; images stay tracked in git.

## Design

### Layout

```
modules/hyprland/files/wallpapers/    # tracked in git
  manifest                            # tracked: assignment file
  <flat image files>                  # tracked, filenames unique
  local/
    manifest                          # gitignored
    <flat image files>                # gitignored
```

- The hyprland `module.toml` already symlinks `files/wallpapers` -> `~/.config/wallpapers` (the dir exists today holding `default.png`, the matugen bootstrap image, which stays untagged). No quill changes needed.
- `.gitignore`: the per-theme rule `modules/hyprland/files/themes/*/wallpapers/local/` is replaced by `modules/hyprland/files/wallpapers/local/`.
- Per-theme `wallpapers/` directories are removed; `themes/<name>/` keeps only config files.
- The directory must not live inside `themes/`: the theme switcher enumerates `themes/*/` as themes and would render a bogus tile.

### Manifest format

```
# filename: theme [theme ...]
ginkgo-temple.jpg: gruvbox-dark kanagawa
ice_castle.png: nord
```

- One line per image: filename, colon, space-separated theme names. `#` comments and blank lines allowed.
- Filenames are flat (no subpaths). The local manifest uses the same format with filenames relative to `local/`.

### Resolution rules

- A file listed for a theme is in that theme's pool.
- A file present on disk but unlisted (or with no themes on its line) is matugen-only: immediately usable by matugen, hidden from static themes until assigned.
- A manifest line whose file does not exist is skipped silently. This tolerates deletions and makes the tracked manifest safe to sync to machines that lack `local/` files.
- Same filename in both the tracked dir and `local/`: the tracked file wins. Documented, not enforced.

### Script changes

All three scripts source a new helper, `modules/hyprland/files/hypr/scripts/lib-wallpapers.sh`:

- `wallpapers_for_theme <name>` — greps both manifests for lines containing the theme, emits absolute paths of files that exist.
- `wallpapers_all` — emits every image file in `wallpapers/` and `wallpapers/local/`.

Consumers:

- `wallpaper-picker.sh`: static-theme pool = `wallpapers_for_theme`; matugen pool = `wallpapers_all` plus the existing `$MATUGEN_WALLPAPERS_DIR` (`~/Pictures/Wallpapers`) union. The sha256 dedupe block is deleted; duplicates are impossible by construction.
- `theme-switcher.sh`: tile icon fallback becomes the first manifest entry for the theme (was: alphabetically first file in the theme's dir). Last-used icon from `wallpapers.txt` state is unchanged.
- `apply-theme.sh`: its wallpaper-resolve step builds the same pools (static pool from the theme's dir, matugen pool from a `find` over all theme dirs) and switches to `wallpapers_for_theme` / `wallpapers_all` likewise. The saved-wallpaper restore from `wallpapers.txt` state is unchanged; state paths stay absolute and now point into `~/.config/wallpapers`.

### Migration (one-off, during implementation)

1. Hash all `themes/*/wallpapers/` files excluding `local/`. First copy is `git mv`ed to `wallpapers/`; further copies are deleted; the set of source theme dirs per hash becomes the tracked manifest. A filename collision between two different images is resolved by prefixing the theme name.
2. `local/` files are moved with plain `mv` (untracked) to `wallpapers/local/`; the local manifest is built the same way.
3. `~/.local/state/themes/wallpapers.txt` paths are rewritten by basename match.
4. Emptied per-theme `wallpapers/` dirs are deleted; `quill apply hyprland` creates the new symlink.

### Verification

- `bash -n` on all changed scripts.
- Smoke-test each user path: picker on a static theme, picker on matugen, switcher tiles, theme apply plus wallpaper restore.
- Matugen picker should open noticeably faster (no hashing).
- `quill apply hyprland` is idempotent on rerun.

## Out of scope

- Repo-size reduction (git-lfs, external storage).
- Per-theme default-wallpaper metadata in `meta.toml`; the icon fallback is manifest order.
- Any change to `~/.config/themes` or the indirection-file mechanism.
