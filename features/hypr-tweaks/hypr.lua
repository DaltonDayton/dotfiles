-- == Resize (SUPER+SHIFT+CTRL+arrows) and move (SUPER+CTRL+ALT+arrows) windows
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

-- == New tiled windows open on the side of the cursor
-- Omarchy's default (2) always splits right/bottom.
hl.config({ dwindle = { force_split = 0 } })

-- == Natural (inverse) touchpad scrolling
hl.config({ input = { touchpad = { natural_scroll = true } } })

-- == Tile Steam's main window (Omarchy floats it)
-- Anchored so it doesn't also match steam_app_battlenet.
o.window({ class = "^steam$", title = "^Steam$" }, { tile = true })

-- == Keep Firefox fully opaque on YouTube
o.window({ class = "^[Ff]irefox$", title = ".*YouTube.*" }, {
  opacity = "1 override 1 override 1 override",
})

-- == Global window opacity: "<active> <inactive>" (Omarchy default: 0.985 0.96)
o.window({ tag = "default-opacity" }, { opacity = "0.95 0.90" })

-- == Pull floating dialogs that open off-screen back to the monitor's centre
-- XWayland sees the stacked monitors side by side, so some X11 dialogs (Unity's
-- Neovim Settings, Unreal's startup toasts) land a monitor-width off the left
-- edge, invisible. Only windows with a real title: Unity (and other X11 apps)
-- park untitled helper windows off-screen on purpose, and dragging those into
-- view leaves Unity thinking a popup is open, which blocks script reloads.
-- Checked at open and once more 250 ms later, for clients that place their
-- window after mapping. Tiled windows are never touched.
local function has_real_title(w)
  local t = (w.title or ""):lower()
  return t ~= "" and t ~= (w.class or ""):lower() and t ~= (w.initial_class or ""):lower()
end

local function recentre_if_offscreen(w)
  if not w.floating or w.monitor == nil or not has_real_title(w) then
    return
  end
  local m = w.monitor
  local off = w.at.x + w.size.x <= m.x
    or w.at.x >= m.x + m.width
    or w.at.y + w.size.y <= m.y
    or w.at.y >= m.y + m.height
  if off then
    hl.dispatch(hl.dsp.window.center({ window = "address:" .. w.address }))
  end
end

hl.on("window.open", function(w)
  recentre_if_offscreen(w)
  hl.timer(function()
    if w.mapped then
      recentre_if_offscreen(w)
    end
  end, { timeout = 250, type = "oneshot" })
end)

-- == Don't let apps steal focus (Omarchy default: focus_on_activate = true)
-- Activation requests just mark the window urgent, as in the pre-Omarchy setup.
-- warp_on_change_workspace off so a focus change elsewhere can't drag the cursor.
hl.config({
  misc = { focus_on_activate = false },
  cursor = { warp_on_change_workspace = 0 },
})
