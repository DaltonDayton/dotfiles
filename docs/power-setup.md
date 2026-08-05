# Laptop power setup (arch-laptop)

Manual `/etc` configuration applied 2026-08-05 on the Dell laptop. Not managed by
quill: one-time hardware config, documented here so a reinstall is a paste job.
If a second machine or more root-owned config shows up, revisit as a `power`
module (would need `files` root support and a `masked` service state in quill).

Related in-repo change: hypridle dim listener in
`modules/hyprland/files/hypr/hypridle.conf` (dim to 10% after 2.5 min idle).

## 1. TLP replaces power-profiles-daemon

TLP tunes more than ppd (USB autosuspend, PCIe ASPM, disk APM, wifi powersave,
per-device runtime PM). The two conflict; ppd stays masked.

```bash
sudo pacman -S tlp
sudo systemctl disable --now power-profiles-daemon
sudo systemctl mask power-profiles-daemon
sudo systemctl enable --now tlp
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket  # TLP owns radio state
```

`/etc/tlp.d/00-laptop.conf` (drop-in survives package updates):

```ini
# CPU on battery
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
CPU_BOOST_ON_BAT=0
PLATFORM_PROFILE_ON_BAT=low-power

# Bus/device power on battery
PCIE_ASPM_ON_BAT=powersupersave
WIFI_PWR_ON_BAT=on
USB_AUTOSUSPEND=1

# Battery lifespan: hold charge at 75-80%
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
```

Then `sudo systemctl restart tlp`.

Notes:

- Charge thresholds use the kernel's native Dell support
  (`/sys/class/power_supply/BAT0/charge_control_*_threshold`, TLP driver
  `natacpi`/`dell_laptop`). No libsmbios needed.
- Full charge for a trip: `sudo tlp fullcharge` (one-shot, reverts on unplug).
- `CPU_BOOST_ON_BAT=0` costs noticeable performance on battery. Remove that
  line if it feels sluggish.

Verify: `sudo tlp-stat -b` (thresholds, "natacpi ... = active"),
`sudo tlp-stat -p` (CPU policy on battery).

## 2. Hibernate: btrfs swapfile + resume

Context: 31G RAM, zram-only swap before this (4G, priority 100, kept). Root is
btrfs on `PARTUUID=b526bafe-4806-4cef-a38c-5d5c8b368a6e`, subvol `@`, no LUKS.
Boot is systemd-boot with a UKI: kernel cmdline lives in `/etc/kernel/cmdline`,
image rebuilt by `mkinitcpio -P` to `/boot/EFI/Linux/arch-linux.efi`.

The setup script (idempotent, re-runnable) did the following; run the steps
manually on a reinstall:

```bash
# 32G swapfile in its own subvolume (nested subvol = excluded from @ snapshots;
# mkswapfile handles NoCOW). Priority defaults below zram, so day-to-day
# swapping still hits zram; the file is effectively hibernate-only.
sudo btrfs subvolume create /swap
sudo btrfs filesystem mkswapfile --size 32g /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
sudo swapon /swap/swapfile

# Resume parameters. resume= is the partition holding the swapfile (root),
# resume_offset is the file's physical offset — recompute it, it changes if
# the swapfile is ever recreated. Was 5573940 on 2026-08-05.
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
# append to /etc/kernel/cmdline:
#   resume=PARTUUID=b526bafe-4806-4cef-a38c-5d5c8b368a6e resume_offset=<offset>

# Busybox initramfs needs the resume hook. In /etc/mkinitcpio.conf HOOKS,
# insert "resume" between "filesystems" and "fsck", then rebuild the UKI:
sudo mkinitcpio -P
```

Verify (order matters — trust lid close only after a manual test):

1. `swapon --show` lists both zram (prio 100) and `/swap/swapfile` (prio -1)
2. `systemctl hibernate` powers off completely
3. Power on resumes the session; `journalctl -b -g 'hibernation exit'` hits in
   the *current* boot

Rollback: remove the two resume params from `/etc/kernel/cmdline`,
`sudo mkinitcpio -P`, `sudo swapoff /swap/swapfile`, remove the fstab line,
delete `/swap`.

## 3. Lid behavior: suspend-then-hibernate

Lid close on battery suspends to RAM (instant wake); if still closed after 2h
the machine wakes briefly, writes RAM to the swapfile, and powers off (zero
drain, resume from disk lands in the same session). On AC it only suspends.

`/etc/systemd/logind.conf.d/lid-hibernate.conf`:

```ini
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
```

`/etc/systemd/sleep.conf.d/hibernate-delay.conf`:

```ini
[Sleep]
HibernateDelaySec=2h
```

Apply: `sudo systemctl kill -s HUP systemd-logind` (reload, keeps sessions).

## 4. Idle chain (hypridle, in-repo)

On idle: dim to 10% at 2.5 min → lock at 5 min → screen off at 5.5 min →
suspend at 30 min. Config: `modules/hyprland/files/hypr/hypridle.conf`.

## Battery health snapshot

2026-08-05: `charge_full` 5988 mAh vs 8339 mAh design = 71.8% capacity.
Thresholds slow further decay; they don't recover lost capacity. Cycle count
unsupported on this pack (reads 0).

## Audit tool

`sudo powertop` → Tunables tab shows remaining offenders. Don't use
`--auto-tune` persistently; TLP already covers those knobs declaratively.
