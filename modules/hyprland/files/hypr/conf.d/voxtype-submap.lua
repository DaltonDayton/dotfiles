-- Voxtype compositor integration
-- Fixes modifier key interference when using compositor keybindings
-- Converted from: voxtype setup compositor hyprland
--
-- Two submaps are used:
-- - voxtype_recording: Active during recording/transcription. F12 cancels.
-- - voxtype_suppress: Active during text output. Blocks modifier keys.
--
-- NOTE: Do not bind Escape in voxtype_suppress. Binding Escape causes wtype's
-- first character to be dropped. See: https://github.com/hyprwm/Hyprland/issues/3165

local mod = "SUPER"

-- Recording submap - active during recording and transcription
hl.define_submap("voxtype_recording", function()
    hl.bind(mod .. " + B", function()
        hl.dispatch(hl.dsp.exec_cmd("voxtype record stop"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind(mod .. " + SHIFT + B", function()
        hl.dispatch(hl.dsp.exec_cmd("voxtype record toggle --clipboard"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("F12", function()
        hl.dispatch(hl.dsp.exec_cmd("voxtype record cancel"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
end)

-- Output submap - blocks modifier keys during text output
hl.define_submap("voxtype_suppress", function()
    for _, key in ipairs({ "SUPER_L", "SUPER_R", "Control_L", "Control_R", "Alt_L", "Alt_R", "Shift_L", "Shift_R" }) do
        hl.bind(key, hl.dsp.exec_cmd("true"))
    end
    hl.bind("F12", hl.dsp.submap("reset")) -- emergency escape if voxtype crashes
end)
