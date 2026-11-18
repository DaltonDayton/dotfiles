# Customizations

Everything on this machine that differs from stock Omarchy, and why. The repo's
features are the first section; the rest is what the repo cannot own yet, kept
here so an Omarchy update can be checked against it. Review workflow and the
automatic checks: `./omarchy-review` (README).

Reviewed against omarchy 4.5.0-3 on 2026-11-18 (desktop). The full audit that
seeded this file is `~/Documents/omarchy-config-report.html`.

## Dotfiles features (desktop profile)

One line per feature, from its `about`. Keys and settings each one layers over
stock, where that matters for a review:

- **bar-tweaks**: clock format `ddd d MMM HH:mm`, battery percentage.
- **basics**: git `[include]`, bash aliases, starship SSH hostname, Claude as agent, screensaver off, shell font size, omarchy-review hook, playerctl.
- **battlenet-tsm**: TSM in its own Wine prefix with Battle.net, floating right; WoW on the games workspace.
- **claude**: global CLAUDE.md, rules, stack notes.
- **cursor-bibata**: Bibata-Modern-Ice cursor (env in `hypr.lua`).
- **desktop-extras**: nfs-utils for `/mnt/stash`, ASMedia USB4 udev fix.
- **dev-envs**: Go, .NET, Python (+uv), Node via `omarchy install dev-env`.
- **font**: CaskaydiaMono Nerd Font (as `omarchy font set` does).
- **ghostty**: default terminal, font-size 10 and opacity 0.9 layered over Omarchy's config.
- **hypr-tweaks**: binds SUPER+CTRL+ALT+arrows (move), F9 hold (dictation). Pins `dwindle.force_split 0`, `input.touchpad.natural_scroll true`, `misc.focus_on_activate false`, `cursor.warp_on_change_workspace 0`. Rules: Steam tiled, Firefox opaque on YouTube. Handlers: recentre off-screen floats, pull floats home after monitor reconnect.
- **idle-inhibit-audio**: no idle lock while audio plays.
- **monitors-desktop**: stacked 3440x1440 ultrawides, scale 1 (snapshot of `monitors.lua`).
- **nightlight-sunset**: hyprsunset at sunset/sunrise (snapshot of `hyprsunset.conf`).
- **nvim**: personal Neovim config, Omarchy's LazyVim moved aside.
- **openrgb**: replays the "default" profile at login.
- **overlayed**: Discord voice overlay, floating top-right.
- **special-workspaces**: binds SUPER+ALT+O (Obsidian), SUPER+ALT+B (Playwright), SUPER+SHIFT+ALT+O.
- **ssh-pve**: SSH host entry for pve over Tailscale.
- **unity**: Unity Editor opaque, Neovim as script editor.
- **unreal**: Unreal/Blender window rules, 10 GB NVIDIA shader cache, nvim-ue.
- **voxtype**: Claude Haiku cleanup, vocabulary, large-v3-turbo (snapshot of voxtype `config.toml`).
- **yt-transcript**: YouTube URL to text via whisper.cpp.

Snapshots (`features/*/upstream`, 3-way merged by `omarchy-diff`): `starship.toml`,
`hypr/monitors.lua`, `hypr/hyprsunset.conf`, voxtype `config.toml`, bar `Workspaces.qml`
(bar-workspaces, currently off the profile).

## Set through Omarchy commands (not in the repo)

Omarchy knows about these; a reinstall would not. `omarchy-review` diffs the
shell.json keys every run.

- **Bar** (`omarchy bar set`, Appearance menu, tray right-click): background `none`; `bitr0t.system-monitor` widget on the left (chip mode instrument; cpu, memory, k10temp Tctl); elsewhen cities Salt Lake City, Sao Paulo, London, Dubai, Tokyo, 24h; power `showPercentage`; tray pins steam, discord, NordVPN, wine TSM; `omarchy.tailscale` widget (Tailscale installer); `superwhisper.panel` in tray (Superwhisper installer); dock section removed.
- **Plugins** (`omarchy plugin add`, unsandboxed): `bitr0t.system-monitor` (rmacy/omarchy-system-monitor v1.2.2), `superwhisper-panel`.
- **Themes** (`omarchy theme install`): amekoji, aura, bauhaus, crimson, crimson-gold, dotrb, dracula, dreamwave, eldritch, florida-man, lavender, sakura, sakura-mochi, sakurazuki, snow_black. Current: catppuccin_custom (see By hand).
- **Fonts**: CaskaydiaMono (font feature), ttf-firacode-nerd also installed from the font menu.
- **Defaults**: agent claude (basics), dictation superwhisper (stock), browser Firefox for http/https/html (stock is Chromium), terminal ghostty (ghostty feature).
- **Weather**: Clinton, UT.
- **DNS** (`omarchy dns`): 192.168.86.12 (AdGuard on pve), Quad9 fallback. Writes `resolved.conf` and `20-omarchy-dns.conf`.
- **Installers**: Steam, Battle.net (umu, `~/Games/battlenet`), Heroic, Minecraft, Tailscale (+ `tailscaled`, `omarchy-tailscale-receive`), NordVPN (`nordvpnd`), Windows VM, Tailscale admin webapp, owe wallpaper engine (`owed.service`, `theme-set.d/10-owe-sync`).
- **Hooks**: `theme-set.d/10-owe-sync` (owe).

## By hand (no record anywhere else)

Candidates for features when they earn it; until then this list is the record.

Config under `~`:
- `~/.config/fontconfig/fonts.conf`: monospace alias bound to CaskaydiaMono so GTK/Qt match the terminals.
- `~/.config/xdg-terminals.list`: ghostty first. Redundant with `omarchy default terminal`.
- `~/.config/git/config`: hand `[user]` and `[credential]` blocks beside the basics include. `config.local` (signing key) still missing.
- `~/.config/git/ignore`: `**/.claude/settings.local.json`.
- `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.zshrc`: installer lines (uv `env`, Unity CLI PATH).
- `~/.config/wireplumber/wireplumber.conf.d/`: `bluetooth-a2dp-autoconnect.conf`, `kef-lsx-no-suspend.conf` (KEF LSX II LT firmware stops on suspend).
- `~/.config/omarchy/themes/catppuccin_custom`: fork of catppuccin, 14 wallpapers, `neovim.lua` uses catppuccin-nvim, icons Yaru-purple.
- `~/.config/omarchy/branding/about.txt`, `screensaver.txt`.
- `~/.XCompose`, Nautilus prefs (icon view, bookmarks, SMB 192.168.86.11), scheme handlers from installers (claude-cli, curseforge, unityhub, superwhisper).
- Desktop files: Blender tarball (`~/software`, `~/.local/bin/blender`), Unity Hub/Editor, 6 Steam shortcuts.

System (`/etc`, services):
- `/etc/fstab`: NTFS `/mnt/4TB_HDD` (currently failing: ntfs3 bad superblock), `/mnt/1TB_HDD` (99% full), NFS automount `/mnt/stash`.
- `/etc/default/limine`: `efi_pstore.pstore_disable=0` (crash investigation). `systemd-pstore.service` is still disabled, so nothing copies pstore records out.
- `/etc/NetworkManager/conf.d/30-homelab-search.conf`: search domain `home.arpa`.
- `/etc/ufw/user.rules`: allow udp 5353 from 192.168.86.0/24 (mDNS).
- `/etc/systemd/system/nordlynx-dnssec.service`: `resolvectl dnssec nordlynx no` when the NordVPN link appears.
- `/etc/cups/printers.conf`: Brother HL-L3220CDW default printer. `cups-browsed` drop-in orphaned (package removed).
- `/etc/udev/rules.d` ASMedia rule (desktop-extras installs it).

Packages outside any feature: CurseForge, discover-overlay-git, gameconqueror/scanmem, vulkan-tools, uv (standalone), bob, git-lfs, android-tools (+ udev, adbusers), freerdp, yazi, openbsd-netcat, graphify; stock `linux` kernel kept beside linux-omarchy.

Services: `voxtype.service` and Superwhisper both enabled (default dictation is Superwhisper).

## Dead weight (safe to delete when convenient)

- `~/.config/omarchy/theme-tweaks/` and `theme-tweaks-record-background.service` (disabled 2026-11-07; Omarchy 4.5 remembers wallpapers itself).
- `~/.config/omarchy/themes/ztest` (380 MB scratch copy, `.hidden` marker nothing honours).
- `~/.config/omarchy/plugins/.dalton.image-picker.bak.*`.
- `~/.config/hypr/hyprland.lua.bak.*`, `hyprsunset.conf.bak.*` (pre-dotfiles backups, content now in features or identical to stock).
- `~/.config/kitty/kitty.conf` (old full config; stock 4.5 is a 21-line overlay).
- `~/.local/state/omarchy/defaults/dictation.lock` (empty leftover).
