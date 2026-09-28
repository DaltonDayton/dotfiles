-- See all bindings: omarchy menu keybindings --print

-- Resize with arrows (alongside Omarchy's SUPER + -/=).
o.bind("SUPER + SHIFT + CTRL + Right", "Resize window wider", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + SHIFT + CTRL + Left", "Resize window narrower", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
o.bind("SUPER + SHIFT + CTRL + Up", "Resize window shorter", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
o.bind("SUPER + SHIFT + CTRL + Down", "Resize window taller", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })

-- Move windows: re-tiles (unlike Omarchy's SUPER+SHIFT+arrows swap), or
-- nudges 30px when floating.
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

-- Special workspaces (rules in hyprland.lua).
o.bind("SUPER + ALT + O", "Toggle Obsidian workspace", hl.dsp.workspace.toggle_special("obsidian"))
o.bind("SUPER + SHIFT + ALT + O", "Move window to Obsidian workspace", hl.dsp.window.move({ workspace = "special:obsidian", follow = true }))
o.bind("SUPER + ALT + B", "Toggle Playwright workspace", hl.dsp.workspace.toggle_special("playwright"))
