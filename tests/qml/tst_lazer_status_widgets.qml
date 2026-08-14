import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Verify uptime formatting and profile fallback behavior.
Item {
    Lazer.ClockWidget { id: clock; testMode: true; enableSystemUptime: false }
    Lazer.UserProfile { id: profile }
    TestCase {
        name: "LazerStatusWidgets"
        function test_uptime() {
            clock.testUptimeText = "3661.23 120.00"
            clock.refresh()
            compare(clock.uptimeText, "已运行 01:01:01")
            clock.testUptimeText = "invalid"
            clock.refresh()
            compare(clock.uptimeText, "已运行 --:--:--")
        }
        function test_profileFallback() {
            profile.username = " Sighthesia "
            compare(profile.fallbackText, "S")
            profile.username = ""
            compare(profile.fallbackText, "?")
        }
    }
}
