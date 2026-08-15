import QtQuick
import QtTest
import "../../modules/lazerbar/FullscreenOverlayLogic.js" as Logic

// Verify the pure route, geometry, and keyboard contracts without Quickshell.
TestCase {
    name: "FullscreenOverlayLogic"

    function test_routesAndToggle() {
        compare(Logic.normalizeRoute("wiki"), "wiki")
        compare(Logic.normalizeRoute("remote"), "")
        compare(Logic.toggleRoute("", "news"), "news")
        compare(Logic.toggleRoute("news", "news"), "")
        compare(Logic.toggleRoute("settings", "beatmap"), "beatmap")
    }

    function test_geometryIsClamped() {
        compare(Logic.surfaceWidth(1920), 1440)
        compare(Logic.surfaceWidth(700), 640)
        verify(Logic.surfaceWidth(300) <= 300)
        verify(Logic.surfaceHeight(40) <= 40)
        verify(Logic.surfaceHeight(300) <= 300)
        compare(Logic.sidebarWidth(100), 176)
        compare(Logic.sidebarWidth(400), 280)
    }

    function test_escapePrecedence() {
        compare(Logic.escapeAction(true, true, true), "input")
        compare(Logic.escapeAction(false, true, true), "back")
        compare(Logic.escapeAction(false, false, true), "close")
        compare(Logic.escapeAction(false, false, false), "none")
    }
}
