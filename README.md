# dotfiles

My overrides on top of [Omarchy](https://omarchy.org/). Omarchy keeps its
defaults in `/usr/share/omarchy/`; this repo holds only what I changed.

## Install

```sh
git clone git@github.com:DaltonDayton/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Symlinks `config/*` into `~/.config/` and `home/*` into `~/`, moving any real
file in the way to `<file>.bak.<epoch>`. `config/hypr/monitors.<hostname>.lua`
becomes `monitors.lua`. It then runs `packages.sh`. Rerun any time.

## Keeping up with Omarchy

Most files here are **layered**: Omarchy loads its defaults, then mine
(`hypr/*.lua`, bar scripts, `.local/bin`). Updates just work.

A few are **snapshots** that replace Omarchy's file outright. Omarchy's version
as of my last sync lives in `upstream/`, so after `omarchy update`:

```sh
./omarchy-diff           # what Omarchy changed since last sync (nothing = up to date)
./omarchy-diff --merge   # 3-way merge it into config/, then review with git diff
```

To track a new snapshot file, copy it into `config/` and its default into
`upstream/` at the same path.

## Once per machine

```sh
omarchy theme set catppuccin                 # background: 3-blue-eye.png
omarchy font set "CaskaydiaMono Nerd Font"
omarchy-toggle screensaver-off on
omarchy default agent claude
omarchy install dev-env <name>   # go, node, python, ruby, dotnet: nvim's mason tools need them
```

- **Git signing:** `~/.config/git/config.local` with `user.signingkey` and `commit.gpgsign`.
- **Desktop only:** keep the ASMedia USB4 chip out of D3cold. It otherwise freezes the machine via the NVIDIA driver:
  ```sh
  sudo cp etc/udev/rules.d/90-asm4242-no-d3cold.rules /etc/udev/rules.d/
  sudo udevadm control --reload && sudo udevadm trigger --action=add --subsystem-match=pci --attr-match=vendor=0x1b21
  ```
- **ImprovedTube:** import `other_configs/improvedtube.json` from the extension's options page.
- **Claude Code ECC plugin:** `/plugin marketplace add affaan-m/ecc`, then `/plugin install ecc@ecc`.

## Scripts

- `nightlight-auto`: night light on at sunset, off at sunrise, for the coordinates at the top of the file. `--dry` previews.
- `yt-transcript <url>`: `.txt` and `.srt` transcript via whisper.cpp on the GPU. `--captions` uses YouTube's subtitles.
- `battlenet-tsm`: TSM and Battle.net in Omarchy's Battle.net prefix. The app menu entry points here.
- `sysmon` (bar): GPU usage and temperature.

The pre-Omarchy setup is archived on `main`.
