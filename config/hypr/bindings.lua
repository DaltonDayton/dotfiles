-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Resize windows with arrows (restored from dotfiles keybindings.lua).
-- Coexists with Omarchy's SUPER + -/= resize set; no unbind needed since
-- Omarchy's SUPER+CTRL+SHIFT bindings are on code:20/code:21, not arrows.
o.bind("SUPER + SHIFT + CTRL + Right", "Resize window wider", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + SHIFT + CTRL + Left", "Resize window narrower", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + SHIFT + CTRL + Up", "Resize window shorter", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
o.bind("SUPER + SHIFT + CTRL + Down", "Resize window taller", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })

-- Move windows (restored from dotfiles keybindings.lua).
-- movewindow restructures the dwindle tree, so surrounding windows resize.
-- Distinct from Omarchy's SUPER+SHIFT+arrows, which is swapwindow: that trades
-- two windows' slots without changing the layout. Both are kept.
-- Floating windows nudge by 30px coordinates instead of re-tiling.
local function move_win(dx, dy, dir)
  return function()
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
      hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
    else
      hl.dispatch(hl.dsp.window.move({ direction = dir }))
    end
  end
end

o.bind("SUPER + CTRL + ALT + Left", "Move window left", move_win(-30, 0, "l"), { repeating = true })
o.bind("SUPER + CTRL + ALT + Right", "Move window right", move_win(30, 0, "r"), { repeating = true })
o.bind("SUPER + CTRL + ALT + Up", "Move window up", move_win(0, -30, "u"), { repeating = true })
o.bind("SUPER + CTRL + ALT + Down", "Move window down", move_win(0, 30, "d"), { repeating = true })
