# Wallpaper Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-theme wallpaper directories with one canonical `wallpapers/` dir plus a manifest that maps each image to its themes.

**Architecture:** Images live flat in `modules/hyprland/files/wallpapers/` (already symlinked to `~/.config/wallpapers`). A tracked `manifest` assigns images to themes; a gitignored `local/` subdir with its own manifest holds unsynced personal images. A sourced bash helper (`lib-wallpapers.sh`) is the single lookup point for the three theme scripts. Untagged images are matugen-only.

**Tech Stack:** bash, git. No Go changes; `module.toml` already has the `files/wallpapers -> ~/.config/wallpapers` symlink.

**Spec:** `docs/superpowers/specs/2026-06-06-wallpaper-manifest-design.md`

**Sequencing note:** Tasks 2-5 form one migration window: after Task 2 the old scripts can't find wallpapers until Tasks 3-5 land. Run Tasks 2-5 back-to-back; full verification is Task 6.

---

### Task 1: lib-wallpapers.sh lookup helper

**Files:**
- Create: `modules/hyprland/files/hypr/scripts/lib-wallpapers.sh`

- [ ] **Step 1: Write the helper**

```bash
#!/usr/bin/env bash
# Manifest-driven wallpaper lookup. Sourced by theme-switcher.sh,
# wallpaper-picker.sh, and apply-theme.sh — not executed directly.
#
# Layout: $WALLPAPERS_DIR/{manifest,*.jpg|png, local/{manifest,*.jpg|png}}
# Manifest line: "<filename>: <theme> [<theme> ...]"; '#' comments allowed.
# A file on disk with no manifest line is matugen-only by design.
# WALLPAPERS_DIR is overridable for tests.

WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/.config/wallpapers}"

# wallpapers_for_theme <theme> [include_local]
# Emits absolute paths assigned to <theme>, manifest order, tracked manifest
# first. Lines whose file is missing are skipped (tolerates deletions and
# local/ files absent on other machines).
wallpapers_for_theme() {
  local theme="$1" include_local="${2:-}"
  local manifests=("$WALLPAPERS_DIR/manifest")
  [[ -n "$include_local" ]] && manifests+=("$WALLPAPERS_DIR/local/manifest")
  local m dir line fname themes
  for m in "${manifests[@]}"; do
    [[ -f "$m" ]] || continue
    dir="$(dirname "$m")"
    while IFS= read -r line; do
      line="${line%%#*}"
      [[ "$line" == *:* ]] || continue
      fname="${line%%:*}"
      themes=" ${line#*:} "
      if [[ "$themes" == *" $theme "* && -f "$dir/$fname" ]]; then
        printf '%s\n' "$dir/$fname"
      fi
    done < "$m"
  done
}

# wallpapers_all [include_local]
# Emits every image file under $WALLPAPERS_DIR (the matugen pool),
# sorted. local/ is excluded unless include_local is non-empty.
wallpapers_all() {
  local include_local="${1:-}"
  local filter=(! -path '*/local/*')
  [[ -n "$include_local" ]] && filter=()
  find -L "$WALLPAPERS_DIR" -type f ${filter[@]+"${filter[@]}"} \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort
}
```

Note `${filter[@]+"${filter[@]}"}`: safe empty-array expansion under `set -u` on old bash; plain `"${filter[@]}"` errors on bash < 4.4 when the array is empty.

- [ ] **Step 2: Syntax check**

Run: `bash -n modules/hyprland/files/hypr/scripts/lib-wallpapers.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Behavior test in a sandbox**

```bash
tmp=$(mktemp -d)
mkdir -p "$tmp/local"
touch "$tmp/a.jpg" "$tmp/b.png" "$tmp/local/c.jpg" "$tmp/d.jpg"
cat > "$tmp/manifest" <<'EOF'
# comment line
a.jpg: nord gruvbox-dark
b.png: nord
missing.png: nord
EOF
printf 'c.jpg: nord\n' > "$tmp/local/manifest"

src='source modules/hyprland/files/hypr/scripts/lib-wallpapers.sh'
WALLPAPERS_DIR="$tmp" bash -euo pipefail -c "$src; wallpapers_for_theme nord"
WALLPAPERS_DIR="$tmp" bash -euo pipefail -c "$src; wallpapers_for_theme nord 1"
WALLPAPERS_DIR="$tmp" bash -euo pipefail -c "$src; wallpapers_for_theme gruvbox-dark"
WALLPAPERS_DIR="$tmp" bash -euo pipefail -c "$src; wallpapers_all"
WALLPAPERS_DIR="$tmp" bash -euo pipefail -c "$src; wallpapers_all 1"
rm -rf "$tmp"
```

Expected, in order:
1. `$tmp/a.jpg` and `$tmp/b.png` (missing.png skipped, c.jpg excluded — no include_local)
2. same plus `$tmp/local/c.jpg`
3. `$tmp/a.jpg` only
4. `$tmp/a.jpg`, `$tmp/b.png`, `$tmp/d.jpg` (d.jpg is untagged but in the all/matugen pool)
5. same plus `$tmp/local/c.jpg`

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/lib-wallpapers.sh
git commit -m "hyprland: add manifest-driven wallpaper lookup helper"
```

---

### Task 2: Migrate wallpapers and build manifests

**Files:**
- Move: `modules/hyprland/files/themes/*/wallpapers/**` -> `modules/hyprland/files/wallpapers/`
- Create: `modules/hyprland/files/wallpapers/manifest`
- Create: `modules/hyprland/files/wallpapers/local/manifest` (gitignored)
- Modify: `.gitignore`
- Modify (runtime state): `~/.local/state/themes/wallpapers.txt`, `~/.local/state/themes/current_wallpaper`

- [ ] **Step 1: Pre-flight — confirm only images live in the theme wallpaper dirs**

```bash
cd modules/hyprland/files
find themes/*/wallpapers -type f ! \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \)
```

Expected: no output. If anything prints, stop and resolve by hand first.

- [ ] **Step 2: Run the tracked-files migration** (from `modules/hyprland/files`)

```bash
bash -euo pipefail <<'MIGRATE'
shopt -s nullglob
declare -A dest_of themes_of
for f in themes/*/wallpapers/*.jpg themes/*/wallpapers/*.jpeg themes/*/wallpapers/*.png; do
  theme=${f#themes/}; theme=${theme%%/*}
  h=$(sha256sum "$f" | cut -d' ' -f1)
  name=$(basename "$f")
  if [[ -z "${dest_of[$h]:-}" ]]; then
    [[ -e "wallpapers/$name" ]] && name="${theme}-${name}"
    git mv "$f" "wallpapers/$name"
    dest_of[$h]="$name"
  else
    git rm -q "$f"
  fi
  [[ "$theme" != "matugen" ]] && themes_of[$h]="${themes_of[$h]:-} ${theme}"
done
{
  echo "# filename: theme [theme ...]"
  for h in "${!dest_of[@]}"; do
    t="${themes_of[$h]:-}"
    [[ -n "$t" ]] && printf '%s:%s\n' "${dest_of[$h]}" "$t"
  done | sort
} > wallpapers/manifest
git add wallpapers/manifest
MIGRATE
```

Notes: first physical copy of a hash is `git mv`ed, later copies `git rm`ed; membership in `matugen/wallpapers/` does not produce a manifest entry (matugen-only is the untagged default). `default.png` already in `wallpapers/` is untouched and stays untagged.

- [ ] **Step 3: Run the local-files migration** (same cwd)

```bash
bash -euo pipefail <<'MIGRATE'
shopt -s nullglob
mkdir -p wallpapers/local
declare -A dest_of themes_of
for f in themes/*/wallpapers/local/*.jpg themes/*/wallpapers/local/*.jpeg themes/*/wallpapers/local/*.png; do
  theme=${f#themes/}; theme=${theme%%/*}
  h=$(sha256sum "$f" | cut -d' ' -f1)
  name=$(basename "$f")
  if [[ -z "${dest_of[$h]:-}" ]]; then
    [[ -e "wallpapers/local/$name" || -e "wallpapers/$name" ]] && name="${theme}-${name}"
    mv "$f" "wallpapers/local/$name"
    dest_of[$h]="$name"
  else
    rm "$f"
  fi
  [[ "$theme" != "matugen" ]] && themes_of[$h]="${themes_of[$h]:-} ${theme}"
done
{
  echo "# filename: theme [theme ...]"
  for h in "${!dest_of[@]}"; do
    t="${themes_of[$h]:-}"
    [[ -n "$t" ]] && printf '%s:%s\n' "${dest_of[$h]}" "$t"
  done | sort
} > wallpapers/local/manifest
MIGRATE
```

- [ ] **Step 4: Remove the emptied per-theme dirs**

```bash
find themes/*/wallpapers -type d -empty -delete
ls -d themes/*/wallpapers 2>/dev/null
```

Expected: second command prints nothing. If a dir survives it still has files — return to Step 1.

- [ ] **Step 5: Update .gitignore** (repo root)

Replace:
```
# Local-only wallpapers (per-theme, not synced).
modules/hyprland/files/themes/*/wallpapers/local/
```
with:
```
# Local-only wallpapers (not synced).
modules/hyprland/files/wallpapers/local/
```

- [ ] **Step 6: Rewrite runtime state paths**

```bash
bash -euo pipefail <<'STATE'
STATE_DIR="$HOME/.local/state/themes"
W="$HOME/.config/wallpapers"
tmp=$(mktemp)
while IFS= read -r line; do
  theme=${line%%:*}; path=${line#*:}; base=$(basename "$path")
  for cand in "$W/$base" "$W/local/$base" "$W/${theme}-${base}" "$W/local/${theme}-${base}"; do
    [[ -f "$cand" ]] && { path="$cand"; break; }
  done
  printf '%s:%s\n' "$theme" "$path"
done < "$STATE_DIR/wallpapers.txt" > "$tmp"
mv "$tmp" "$STATE_DIR/wallpapers.txt"
cw="$STATE_DIR/current_wallpaper"
if [[ -L "$cw" && ! -e "$cw" ]]; then
  base=$(basename "$(readlink "$cw")")
  for cand in "$W/$base" "$W/local/$base"; do
    [[ -f "$cand" ]] && { ln -sfn "$cand" "$cw"; break; }
  done
fi
STATE
cat "$HOME/.local/state/themes/wallpapers.txt"
readlink -f "$HOME/.local/state/themes/current_wallpaper"
```

Expected: every state line points at an existing file under `~/.config/wallpapers/`; the `current_wallpaper` symlink resolves.

- [ ] **Step 7: Sanity-check the result**

```bash
cd "$(git rev-parse --show-toplevel)"
wc -l modules/hyprland/files/wallpapers/manifest
ls modules/hyprland/files/wallpapers | head
git status --short | grep -c "^R" || true
bash -c 'source modules/hyprland/files/hypr/scripts/lib-wallpapers.sh; wallpapers_for_theme nord'
```

Expected: manifest has roughly one line per unique tracked image (about 80-105 lines given 132 files minus 26 duplicate copies minus local files); the nord lookup prints existing absolute paths under `~/.config/wallpapers/`.

- [ ] **Step 8: Commit**

```bash
git add -A modules/hyprland/files/themes modules/hyprland/files/wallpapers .gitignore
git commit -m "hyprland: move wallpapers to central manifest-driven dir"
```

---

### Task 3: wallpaper-picker.sh uses the manifest

**Files:**
- Modify: `modules/hyprland/files/hypr/scripts/wallpaper-picker.sh`

- [ ] **Step 1: Source the helper**

After the `set -euo pipefail` line, and replacing the `THEMES_DIR=` line (the picker no longer reads theme dirs; `THEMES_DIR` is only used for `meta.toml` below, so keep it):

```bash
THEMES_DIR="$HOME/.config/themes"
source "$HOME/.config/hypr/scripts/lib-wallpapers.sh"
```

- [ ] **Step 2: Delete the find_filter block**

Remove these lines (the manifest split replaces path-filtering):

```bash
find_filter=()
[[ -z "$INCLUDE_LOCAL" ]] && find_filter=(! -path '*/local/*')
```

Keep `INCLUDE_LOCAL="${WALLPAPER_PICKER_INCLUDE_LOCAL:-}"` — it now feeds the helper calls, and Alt+L relaunch is unchanged.

- [ ] **Step 3: Replace the whole "Build pool" block** (from `# Build pool` through the closing `fi` of the static branch) with:

```bash
# Build pool
declare -a pool=()
if [[ "$mode" == "matugen" ]]; then
  matugen_extra_dir="${MATUGEN_WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}"
  mapfile -t pool < <(
    {
      wallpapers_all "$INCLUDE_LOCAL"
      if [[ -d "$matugen_extra_dir" ]]; then
        find -L "$matugen_extra_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \)
      fi
    } | sort -u
  )
else
  mapfile -t pool < <(wallpapers_for_theme "$THEME" "$INCLUDE_LOCAL")
fi
```

This deletes the sha256 dedupe loop entirely; the manifest makes duplicates structurally impossible, and `sort -u` covers an image present in both `~/.config/wallpapers` and `~/Pictures/Wallpapers` only if it is the same absolute path (different copies in the extra dir are out of scope, as before).

- [ ] **Step 4: Syntax check and smoke test**

```bash
bash -n modules/hyprland/files/hypr/scripts/wallpaper-picker.sh
timeout 4 bash ~/.config/hypr/scripts/wallpaper-picker.sh </dev/null; echo "exit=$?"
```

Expected: `bash -n` silent; the run exits 124 (rofi opened with the current theme's pool until timeout). Run with a static theme active.

- [ ] **Step 5: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/wallpaper-picker.sh
git commit -m "hyprland: wallpaper picker reads manifest, drop sha256 dedupe"
```

---

### Task 4: theme-switcher.sh icon fallback from manifest

**Files:**
- Modify: `modules/hyprland/files/hypr/scripts/theme-switcher.sh`

- [ ] **Step 1: Source the helper**

After the `ROFI_THUMBNAIL_CMD=` line:

```bash
source "$HOME/.config/hypr/scripts/lib-wallpapers.sh"
```

- [ ] **Step 2: Replace the icon fallback**

Replace:

```bash
  if [[ -z "$icon" ]]; then
    icon=$(find -L "$THEMES_DIR/$d/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort | head -n1)
  fi
```

with:

```bash
  if [[ -z "$icon" ]]; then
    icon=$(wallpapers_for_theme "$d" 1 | head -n1 || true)
  fi
```

(`1` = include local, matching the old behavior where local files could serve as tile icons; `|| true` guards the `head` SIGPIPE under pipefail.)

- [ ] **Step 3: Syntax check and smoke test**

```bash
bash -n modules/hyprland/files/hypr/scripts/theme-switcher.sh
timeout 4 bash ~/.config/hypr/scripts/theme-switcher.sh </dev/null; echo "exit=$?"
```

Expected: silent syntax check; exit 124 with the grid showing a thumbnail per theme (manifest-assigned themes get icons; matugen tile falls back to its last-used entry in wallpapers.txt, else no icon).

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/theme-switcher.sh
git commit -m "hyprland: theme switcher icons from wallpaper manifest"
```

---

### Task 5: apply-theme.sh pools from manifest

**Files:**
- Modify: `modules/hyprland/files/hypr/scripts/apply-theme.sh`

- [ ] **Step 1: Source the helper**

After the `APPLY` / state-dir variable block near the top (alongside the other `$HOME/.config/hypr/scripts` reference):

```bash
source "$HOME/.config/hypr/scripts/lib-wallpapers.sh"
```

- [ ] **Step 2: Replace the "Build wallpaper pool" block** (the `declare -a pool=()` through the closing `fi`) with:

```bash
# --- Build wallpaper pool -----------------------------------------------------
declare -a pool=()
if [[ "$mode" == "matugen" ]]; then
  matugen_extra_dir="${MATUGEN_WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}"
  mapfile -t pool < <(
    {
      wallpapers_all 1
      if [[ -d "$matugen_extra_dir" ]]; then
        find -L "$matugen_extra_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \)
      fi
    } | sort -u
  )
else
  mapfile -t pool < <(wallpapers_for_theme "$THEME" 1)
fi
```

(`1` = include local in both modes: apply-theme's old `find`s had no local exclusion, and a restored last-used wallpaper may be a local file.)

- [ ] **Step 3: Syntax check and smoke test via the real path**

```bash
bash -n modules/hyprland/files/hypr/scripts/apply-theme.sh
bash ~/.config/hypr/scripts/apply-theme.sh "$(cat ~/.local/state/themes/current)"; echo "exit=$?"
```

Expected: exit 0; desktop re-applies the current theme; wallpaper restored from state (unchanged on screen).

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/apply-theme.sh
git commit -m "hyprland: apply-theme builds wallpaper pools from manifest"
```

---

### Task 6: End-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Lookup spot-checks**

```bash
source modules/hyprland/files/hypr/scripts/lib-wallpapers.sh
wallpapers_for_theme gruvbox-dark
wallpapers_for_theme nord 1
wallpapers_all | wc -l
```

Expected: each static theme lists its images; counts match the manifest.

- [ ] **Step 2: Picker on a static theme** — Super+Shift+D (or the timeout invocation from Task 3). Pool shows only that theme's assigned wallpapers; Alt+L reveals local ones; selecting one sets the wallpaper and updates `wallpapers.txt`.

- [ ] **Step 3: Picker on matugen** — switch to the Matugen theme via Super+D, then Super+Shift+D. Pool shows every image (tagged + untagged + `~/Pictures/Wallpapers`) exactly once, and opens with no hashing delay.

- [ ] **Step 4: Theme switching round-trip** — Super+D, pick another theme, pick the original back. Tiles all have thumbnails; wallpaper restores per theme.

- [ ] **Step 5: Quill idempotency**

```bash
go build -o ./bin/quill ./cmd/quill && ./bin/quill apply hyprland && ./bin/quill apply hyprland
```

Expected: both applies succeed; second run reports already-satisfied state (symlink unchanged).

- [ ] **Step 6: Update the spec status line** — set `Status: implemented` in `docs/superpowers/specs/2026-06-06-wallpaper-manifest-design.md`, commit:

```bash
git add docs/superpowers/specs/2026-06-06-wallpaper-manifest-design.md
git commit -m "docs: mark wallpaper manifest spec implemented"
```
