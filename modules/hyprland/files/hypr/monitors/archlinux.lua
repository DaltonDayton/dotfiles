-- Desktop — two ultrawide monitors (3440x1440), stacked vertically.
-- Matched by description, not port name: DP-N numbering shifted across the
-- 2026-07 reinstall (DP-2/DP-3 -> DP-4/DP-5) and desc survives that.

-- Top monitor — AOC, positioned above primary
hl.monitor({ output = "desc:AOC U34G2G4R3 0x000099D5", mode = "3440x1440@144", position = "0x-1440", scale = 1, vrr = 0 })

-- Bottom monitor (primary) — Samsung
hl.monitor({ output = "desc:Samsung Electric Company LC34G55T H1AK500000", mode = "3440x1440@165", position = "0x0", scale = 1, vrr = 0 })

-- HYTE Y70ti case monitor — right of bottom ultrawide, rotated 270 degrees.
-- Not detected since the reinstall; re-enable by desc once it shows up in
-- `hyprctl monitors all`.
-- hl.monitor({ output = "<desc>", mode = "3840x1100@60", position = "3440x0", scale = 1, transform = 3 })

-- Workspace-to-monitor assignments — Samsung is primary
hl.workspace_rule({ workspace = "1", monitor = "desc:Samsung Electric Company LC34G55T H1AK500000", default = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:AOC U34G2G4R3 0x000099D5", default = true })
