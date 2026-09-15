import QtQuick
import QtTest
import "../../services/SolarCalc.js" as SolarCalc

// Unit-test the offline solar timetable: validation, HH:MM formatting,
// NOAA calculation against known references, polar day/night, and fallbacks.
Item {
    TestCase {
        name: "SolarCalc"

        function test_validation() {
            verify(SolarCalc.isValidLatitude(0))
            verify(SolarCalc.isValidLatitude(90))
            verify(SolarCalc.isValidLatitude(-90))
            verify(!SolarCalc.isValidLatitude(91))
            verify(!SolarCalc.isValidLatitude("abc"))
            verify(SolarCalc.isValidLongitude(180))
            verify(SolarCalc.isValidLongitude(-180))
            verify(!SolarCalc.isValidLongitude(181))
            verify(!SolarCalc.isValidLongitude(""))
        }

        function test_minutesToHHMM() {
            compare(SolarCalc.minutesToHHMM(390), "06:30")
            compare(SolarCalc.minutesToHHMM(0), "00:00")
            compare(SolarCalc.minutesToHHMM(1439), "23:59")
            compare(SolarCalc.minutesToHHMM(1440), "00:00")
            compare(SolarCalc.minutesToHHMM(-1), "23:59")
        }

        function _closeEnough(actual, expected, tolerance) {
            var diff = Math.abs(actual - expected)
            diff = Math.min(diff, 1440 - diff)
            return diff <= tolerance
        }

        function test_beijingSummerSolstice() {
            // Beijing 39.90N 116.40E, 2026-06-21, UTC+8 (480).
            // Reference: sunrise ~04:45, sunset ~19:46 (±15min tolerance).
            var r = SolarCalc.calcSunTimes(2026, 6, 21, 39.90, 116.40, 480)
            verify(!r.polarDay)
            verify(!r.polarNight)
            verify(_closeEnough(r.sunriseMinutes, 4 * 60 + 45, 15))
            verify(_closeEnough(r.sunsetMinutes, 19 * 60 + 46, 15))
            verify(r.sunriseMinutes < r.sunsetMinutes)
        }

        function test_equatorEquinox() {
            // Equator at Greenwich, 2026-03-20, UTC+0: ~06:00/18:00 day.
            var r = SolarCalc.calcSunTimes(2026, 3, 20, 0, 0, 0)
            verify(!r.polarDay)
            verify(!r.polarNight)
            verify(_closeEnough(r.sunriseMinutes, 360, 25))
            verify(_closeEnough(r.sunsetMinutes, 1080, 25))
        }

        function test_polarDay() {
            // Longyearbyen 78.22N, June: sun never sets.
            var r = SolarCalc.calcSunTimes(2026, 6, 21, 78.22, 15.63, 120)
            verify(r.polarDay)
            verify(!r.polarNight)
            compare(r.sunriseMinutes, 0)
        }

        function test_polarNight() {
            // Longyearbyen 78.22N, December: sun never rises.
            var r = SolarCalc.calcSunTimes(2026, 12, 21, 78.22, 15.63, 60)
            verify(r.polarNight)
            verify(!r.polarDay)
        }

        function test_invalidFallsBack() {
            var r = SolarCalc.calcSunTimes(2026, 6, 21, 999, 0, 480)
            compare(r.sunrise, "06:30")
            compare(r.sunset, "18:30")
            var r2 = SolarCalc.calcSunTimes(2026, 6, 21, 39.9, 116.4, NaN)
            compare(r2.sunrise, "06:30")
        }

        function test_sunTimesForDate() {
            var d = new Date(2026, 5, 21, 12, 0, 0)
            var r = SolarCalc.sunTimesForDate(d, 39.90, 116.40)
            verify(r.sunrise.length === 5)
            verify(r.sunset.length === 5)
            verify(r.sunriseMinutes >= 0 && r.sunriseMinutes < 1440)
        }
    }
}
