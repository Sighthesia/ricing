import QtQuick
import QtTest
import "../../modules/lazerbar/LazerBarLogic.js" as Logic

// Verify deterministic lazer bar formatting and layout decisions.
Item {
    TestCase {
        name: "LazerBarLogic"

        function test_durationFormatting() {
            compare(Logic.formatDuration(0), "00:00:00")
            compare(Logic.formatDuration(3661), "01:01:01")
            compare(Logic.formatDuration(360005), "100:00:05")
            compare(Logic.formatDuration(-1), "--:--:--")
        }

        function test_uptimeParsing() {
            compare(Logic.parseUptime("9876.54 1234.00\n"), 9876)
            compare(Logic.parseUptime("not uptime"), -1)
        }

        function test_fallbackInitial() {
            compare(Logic.fallbackInitial(" Sighthesia "), "S")
            compare(Logic.fallbackInitial(""), "?")
        }

        function test_visualStateComposition() {
            compare(Logic.visualState(true, true, true, true), "activePressed")
            compare(Logic.visualState(false, true, true, true), "disabled")
        }

        function test_popupOrigin() {
            compare(Logic.popupOrigin(40, 220, 1920), "topLeft")
            compare(Logic.popupOrigin(1880, 220, 1920), "topRight")
        }

        function test_responsiveUtilities() {
            compare(Logic.visibleUtilityIds(32, 32, 12), ["music"])
            compare(Logic.visibleUtilityIds(340, 32, 12), [
                "news", "changelog", "wiki", "ranking",
                "library", "chat", "community", "music"
            ])
        }
    }
}
