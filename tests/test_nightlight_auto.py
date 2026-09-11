"""Tests for home/.local/bin/nightlight-auto.

Run with: python -m unittest discover tests
Expected sun times are from published almanac data for Clinton, UT, so the
tolerance covers the NOAA approximation plus rounding to the minute.
"""
import importlib.util
import sys
sys.dont_write_bytecode = True  # keep __pycache__ out of home/.local/bin, which install.sh links
import unittest
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

SCRIPT = Path(__file__).resolve().parent.parent / "home/.local/bin/nightlight-auto"
spec = importlib.util.spec_from_file_location("nightlight_auto", SCRIPT,
                                              loader=importlib.machinery.SourceFileLoader("nightlight_auto", str(SCRIPT)))
na = importlib.util.module_from_spec(spec)
spec.loader.exec_module(na)

TZ = ZoneInfo("America/Denver")
LAT, LON = 41.14, -112.05
TOL = timedelta(minutes=5)


def at(y, m, d, hh, mm):
    return datetime(y, m, d, hh, mm, tzinfo=TZ)


class SunTimes(unittest.TestCase):
    def check(self, day, rise, set_):
        got_rise, got_set = na.sun_times(day, LAT, LON, TZ)
        self.assertAlmostEqual(got_rise, rise, delta=TOL)
        self.assertAlmostEqual(got_set, set_, delta=TOL)

    def test_summer_solstice(self):
        self.check(date(2026, 6, 21), at(2026, 6, 21, 5, 57), at(2026, 6, 21, 21, 3))

    def test_winter_solstice(self):
        self.check(date(2026, 12, 21), at(2026, 12, 21, 7, 49), at(2026, 12, 21, 17, 4))

    def test_spring_equinox(self):
        self.check(date(2026, 3, 20), at(2026, 3, 20, 7, 36), at(2026, 3, 20, 19, 44))

    def test_results_are_in_requested_zone(self):
        rise, _ = na.sun_times(date(2026, 6, 21), LAT, LON, TZ)
        self.assertEqual(rise.tzinfo, TZ)


class Decide(unittest.TestCase):
    """decide(now) -> (night, next_transition)."""

    def test_midday_is_day_and_next_is_tonights_sunset(self):
        night, nxt = na.decide(at(2026, 6, 21, 12, 0), LAT, LON)
        self.assertFalse(night)
        self.assertAlmostEqual(nxt, at(2026, 6, 21, 21, 3), delta=TOL)

    def test_before_dawn_is_night_and_next_is_todays_sunrise(self):
        night, nxt = na.decide(at(2026, 6, 21, 3, 0), LAT, LON)
        self.assertTrue(night)
        self.assertAlmostEqual(nxt, at(2026, 6, 21, 5, 57), delta=TOL)

    def test_after_dusk_is_night_and_next_is_tomorrows_sunrise(self):
        night, nxt = na.decide(at(2026, 12, 21, 22, 0), LAT, LON)
        self.assertTrue(night)
        self.assertAlmostEqual(nxt, at(2026, 12, 22, 7, 49), delta=TOL)

    def test_next_transition_is_always_in_the_future(self):
        for hour in range(24):
            now = at(2026, 9, 10, hour, 30)
            _, nxt = na.decide(now, LAT, LON)
            self.assertGreater(nxt, now, msg=f"hour {hour}")


if __name__ == "__main__":
    unittest.main()
