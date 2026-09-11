-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Hold a Wayland idle inhibitor whenever anything is playing or recording
-- audio. Browsers only inhibit for video, and only while that video is
-- actually visible, so without this a podcast -- or a YouTube tab behind
-- another window -- still hits the idle lock. Installed by packages.sh.
--
-- It has to be a *Wayland* inhibitor. Omarchy's idle service is Quickshell's
-- IdleMonitor over Hyprland's ext-idle-notify-v1, so the only thing it honors
-- is zwp_idle_inhibit_manager_v1. sway-audio-idle-inhibit looks like the
-- obvious choice and is useless here: it doesn't link libwayland at all, it
-- takes a systemd-logind "idle" lock, and logind's idle lock only gates
-- IdleAction= in logind.conf. Nothing in Omarchy reads it.
o.launch_on_start("wayland-pipewire-idle-inhibit")

-- Night light on at sunset, off at sunrise. hyprsunset only does fixed clock
-- times, so this computes the real ones and books a systemd timer for the next
-- transition; see home/.local/bin/nightlight-auto.
o.launch_on_start("nightlight-auto")
