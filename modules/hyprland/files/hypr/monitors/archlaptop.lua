-- Laptop — built-in display
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })

-- Laptop GPU workaround
hl.env("AQ_NO_MODIFIERS", "1")

-- Acer Z35P ultrawide
hl.monitor({ output = "desc:Acer Technologies Z35P T3ZAA0038511", mode = "3440x1440@50", position = "auto", scale = 1 })

-- Fallback — auto-detect any other connected monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
