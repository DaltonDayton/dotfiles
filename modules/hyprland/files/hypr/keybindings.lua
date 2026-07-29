-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local programs = require("programs")

local mod = "SUPER"
local browser = "firefox"

-- Application shortcuts
hl.bind(mod .. " + E", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mod .. " + T", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + F", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(programs.menu))

-- Window state
hl.bind(mod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + Return", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("systemctl --user start hyprlock-watch.service"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("wlogout"))

-- Window navigation
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Move active window around current workspace (floating windows move by
-- coordinates, tiled windows swap in the direction).
local moveactive = 'grep -q "true" <<< $(hyprctl activewindow -j | jq -r .floating) && hyprctl dispatch moveactive'
hl.bind(mod .. " + SHIFT + left", hl.dsp.exec_cmd(moveactive .. " -30 0 || hyprctl dispatch movewindow l"), { description = "Move active window to the left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.exec_cmd(moveactive .. " 30 0 || hyprctl dispatch movewindow r"), { description = "Move active window to the right" })
hl.bind(mod .. " + SHIFT + up", hl.dsp.exec_cmd(moveactive .. " 0 -30 || hyprctl dispatch movewindow u"), { description = "Move active window up" })
hl.bind(mod .. " + SHIFT + down", hl.dsp.exec_cmd(moveactive .. " 0 30 || hyprctl dispatch movewindow d"), { description = "Move active window down" })

-- Resize windows
hl.bind(mod .. " + SHIFT + CTRL + Right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + CTRL + Left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })

-- Move/resize windows with mouse drag
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspaces 1-10: switch, move, move silently
for i = 1, 10 do
    local key = tostring(i % 10) -- workspace 10 lives on the 0 key
    local ws = tostring(i)
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws, follow = true }))
    hl.bind(mod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Relative workspaces
hl.bind(mod .. " + CTRL + ALT + Right", hl.dsp.window.move({ workspace = "r+1", follow = true }))
hl.bind(mod .. " + CTRL + ALT + Left", hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + CTRL + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + CTRL + Down", hl.dsp.focus({ workspace = "empty" }))

-- Scratchpad
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

-- Scroll through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Special workspace shortcuts
local specials = { M = "music", F = "files", T = "monitoring", O = "obsidian", B = "playwright" }
for key, name in pairs(specials) do
    hl.bind(mod .. " + ALT + " .. key, hl.dsp.workspace.toggle_special(name))
end
local special_moves = { M = "music", F = "files", T = "monitoring", O = "obsidian" }
for key, name in pairs(special_moves) do
    hl.bind(mod .. " + SHIFT + ALT + " .. key, hl.dsp.window.move({ workspace = "special:" .. name, follow = true }))
end

-- Multimedia (laptop volume/brightness keys)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Laptop lid switch: disable/enable built-in display
hl.bind("switch:on:Lid Switch", function()
    hl.monitor({ output = "eDP-1", mode = "disable" })
end, { locked = true })
hl.bind("switch:off:Lid Switch", function()
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })
end, { locked = true })

-- Media control (requires playerctl)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Screen capture (requires grimblast, satty, wf-recorder, slurp)
hl.bind(mod .. " + P", hl.dsp.exec_cmd([[grimblast --freeze copysave area /tmp/screenshot.png && satty --filename /tmp/screenshot.png --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H%M%S).png]]))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd([[grimblast copysave output /tmp/screenshot.png && satty --filename /tmp/screenshot.png --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H%M%S).png]]))
hl.bind(mod .. " + ALT + P", hl.dsp.exec_cmd([[grimblast copysave screen /tmp/screenshot.png && satty --filename /tmp/screenshot.png --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H%M%S).png]]))
hl.bind(mod .. " + G", hl.dsp.exec_cmd([[pkill -INT wf-recorder || (notify-send "GIF Recording" "Select region to record" -t 2000 && wf-recorder -g "$(slurp)" -c gif -r 10 -f ~/Videos/GIFs/recording-$(date +%Y%m%d-%H%M%S).gif && notify-send "GIF Recording" "Saved to ~/Videos/GIFs/")]]))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd([[pkill -INT wf-recorder || (notify-send "MP4 Recording" "Select region to record" -t 2000 && wf-recorder -g "$(slurp)" -f ~/Videos/Recordings/recording-$(date +%Y%m%d-%H%M%S).mp4 && notify-send "MP4 Recording" "Saved to ~/Videos/Recordings/")]]))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/ocr-screenshot.sh"))

-- Theming
hl.bind(mod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/theme-switcher.sh"))
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-picker.sh"))

-- Panels and clipboard
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd([[cliphist wipe && wl-copy --clear && notify-send "Clipboard" "History cleared"]]))
hl.bind(mod .. " + U", hl.dsp.exec_cmd([[u=$(uuidgen) && printf %s "$u" | wl-copy && notify-send "UUID copied" "$u"]]))

-- Voice dictation (requires voxtype, wtype)
hl.bind(mod .. " + B", hl.dsp.exec_cmd("voxtype record toggle"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("voxtype record toggle --clipboard"))
