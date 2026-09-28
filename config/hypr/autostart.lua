-- Block idle lock while audio plays (browsers only inhibit for visible video).
o.launch_on_start("wayland-pipewire-idle-inhibit")

-- Night light on at sunset, off at sunrise (~/.local/bin/nightlight-auto).
o.launch_on_start("nightlight-auto")
