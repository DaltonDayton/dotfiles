-- Set the lights once per login, then exit: nothing stays resident. Save the
-- profile as "default" in the OpenRGB GUI (~/.config/OpenRGB/default.orp).
o.exec_on_start("openrgb -p default")
