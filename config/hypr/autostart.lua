-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Hold a Wayland idle inhibitor whenever anything is playing or recording
-- audio. Browsers only inhibit for video, so without this a podcast or a
-- music tab still hits the idle lock. Installed by packages.sh.
o.launch_on_start("sway-audio-idle-inhibit")
