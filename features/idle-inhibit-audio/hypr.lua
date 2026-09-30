-- Browsers only inhibit for visible video. Must be a Wayland inhibitor:
-- Omarchy's idle service ignores logind's idle lock.
o.launch_on_start("wayland-pipewire-idle-inhibit")
