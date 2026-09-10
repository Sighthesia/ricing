import QtQuick
import QtTest
import "../../services/ColorSchemeLogic.js" as ColorLogic

// Unit-test the automatic light/dark scheduling math: normalization,
// HH:MM parsing, day/night resolution (including overnight ranges), and
// effective-mode resolution across manual/time/system intents.
Item {
    TestCase {
        name: "ColorSchemeLogic"

        function test_normalizeColorScheme() {
            compare(ColorLogic.normalizeColorScheme("dark"), "dark")
            compare(ColorLogic.normalizeColorScheme("light"), "light")
            compare(ColorLogic.normalizeColorScheme("auto"), "auto")
            compare(ColorLogic.normalizeColorScheme("invalid"), "auto")
            compare(ColorLogic.normalizeColorScheme(""), "auto")
            compare(ColorLogic.normalizeColorScheme(undefined), "auto")
            compare(ColorLogic.normalizeColorScheme(null), "auto")
        }

        function test_normalizeAutoMode() {
            compare(ColorLogic.normalizeAutoMode("time"), "time")
            compare(ColorLogic.normalizeAutoMode("system"), "system")
            compare(ColorLogic.normalizeAutoMode("invalid"), "time")
            compare(ColorLogic.normalizeAutoMode(""), "time")
            compare(ColorLogic.normalizeAutoMode(undefined), "time")
        }

        function test_parseTimeMinutes() {
            compare(ColorLogic.parseTimeMinutes("06:30"), 390)
            compare(ColorLogic.parseTimeMinutes("18:30"), 1110)
            compare(ColorLogic.parseTimeMinutes("6:05"), 365)
            compare(ColorLogic.parseTimeMinutes("6:5"), 365)
            compare(ColorLogic.parseTimeMinutes("06:5"), 365)
            compare(ColorLogic.parseTimeMinutes("00:00"), 0)
            compare(ColorLogic.parseTimeMinutes("23:59"), 1439)
            compare(ColorLogic.parseTimeMinutes("24:00"), -1)
            compare(ColorLogic.parseTimeMinutes("12:60"), -1)
            compare(ColorLogic.parseTimeMinutes("abc"), -1)
            compare(ColorLogic.parseTimeMinutes(""), -1)
            compare(ColorLogic.parseTimeMinutes("6:555"), -1)
            compare(ColorLogic.parseTimeMinutes("6:"), -1)
            compare(ColorLogic.parseTimeMinutes(null), -1)
        }

        function test_normalizeTimeString() {
            compare(ColorLogic.normalizeTimeString("6:05", "06:30"), "06:05")
            compare(ColorLogic.normalizeTimeString(" 18:30 ", "06:30"), "18:30")
            compare(ColorLogic.normalizeTimeString("garbage", "06:30"), "06:30")
            compare(ColorLogic.normalizeTimeString("", "18:30"), "18:30")
            compare(ColorLogic.normalizeTimeString("garbage", "garbage"), "00:00")
            compare(ColorLogic.normalizeTimeString("25:00", "07:15"), "07:15")
        }

        function test_isDarkAtMinutes_dayBoundaries() {
            var rise = 390 // 06:30
            var set = 1110 // 18:30
            verify(ColorLogic.isDarkAtMinutes(0, rise, set))
            verify(ColorLogic.isDarkAtMinutes(389, rise, set))
            verify(!ColorLogic.isDarkAtMinutes(390, rise, set))
            verify(!ColorLogic.isDarkAtMinutes(720, rise, set))
            verify(!ColorLogic.isDarkAtMinutes(1109, rise, set))
            verify(ColorLogic.isDarkAtMinutes(1110, rise, set))
            verify(ColorLogic.isDarkAtMinutes(1439, rise, set))
        }

        function test_isDarkAtMinutes_overnightRange() {
            // Polar-style timetable: day wraps past midnight.
            verify(!ColorLogic.isDarkAtMinutes(0, 1200, 360))
            verify(!ColorLogic.isDarkAtMinutes(359, 1200, 360))
            verify(ColorLogic.isDarkAtMinutes(360, 1200, 360))
            verify(ColorLogic.isDarkAtMinutes(1199, 1200, 360))
            verify(!ColorLogic.isDarkAtMinutes(1200, 1200, 360))
        }

        function test_isDarkAtMinutes_invalidFallsBackToDefaults() {
            verify(ColorLogic.isDarkAtMinutes(0, -1, -1))
            verify(!ColorLogic.isDarkAtMinutes(720, -1, -1))
            compare(ColorLogic.isDarkAtMinutes(0, -1, -1),
                    ColorLogic.isDarkAtMinutes(0, 390, 1110))
        }

        function test_effectiveMode_manualPassesThrough() {
            compare(ColorLogic.effectiveMode("dark", "time", "06:30", "18:30", 720, "light"), "dark")
            compare(ColorLogic.effectiveMode("light", "system", "06:30", "18:30", 0, "dark"), "light")
            compare(ColorLogic.effectiveMode("invalid", "time", "06:30", "18:30", 720, "unknown"), "light")
        }

        function test_effectiveMode_autoTime() {
            compare(ColorLogic.effectiveMode("auto", "time", "06:30", "18:30", 720, "unknown"), "light")
            compare(ColorLogic.effectiveMode("auto", "time", "06:30", "18:30", 0, "unknown"), "dark")
            compare(ColorLogic.effectiveMode("auto", "invalid", "06:30", "18:30", 0, "unknown"), "dark")
        }

        function test_effectiveMode_autoSystem() {
            compare(ColorLogic.effectiveMode("auto", "system", "06:30", "18:30", 720, "dark"), "dark")
            compare(ColorLogic.effectiveMode("auto", "system", "06:30", "18:30", 0, "light"), "light")
            // Unknown OS scheme falls back to the timetable (midnight -> dark).
            compare(ColorLogic.effectiveMode("auto", "system", "06:30", "18:30", 0, "unknown"), "dark")
            compare(ColorLogic.effectiveMode("auto", "system", "06:30", "18:30", 0, "garbage"), "dark")
        }
    }
}
