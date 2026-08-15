import QtQuick
import QtTest
import "../../modules/lazerbar/FullscreenOverlayLogic.js" as Logic
import "../../modules/lazerbar/OsuOverlayPalette.js" as Palette

// Verify the pure route, geometry, and keyboard contracts without Quickshell.
TestCase {
    name: "FullscreenOverlayLogic"

    function test_routesAndToggle() {
        compare(Logic.normalizeRoute("wiki"), "wiki")
        compare(Logic.normalizeRoute("settings"), "")
        compare(Logic.normalizeRoute("remote"), "")
        compare(Logic.toggleRoute("", "news"), "news")
        compare(Logic.toggleRoute("news", "news"), "")
        compare(Logic.toggleRoute("wiki", "beatmap"), "beatmap")
    }

    function test_waveGeometry() {
        compare(Logic.surfaceWidth(1920), 1632)
        compare(Logic.surfaceWidth(800), 680)
        compare(Logic.surfaceWidth(-100), 0)
        compare(Logic.surfaceTop("top", 46), 46)
        compare(Logic.surfaceTop("bottom", 46), 0)
        compare(Logic.waveAngle(0), 13)
        compare(Logic.waveAngle(1), -7)
        compare(Logic.waveAngle(2), 4)
        compare(Logic.waveAngle(3), -2)
        compare(Logic.waveAngle(4), 0)
        compare(Logic.sidebarWidth(100), 176)
        compare(Logic.sidebarWidth(400), 280)
    }

    function test_fixedRoutePalettes() {
        compare(Palette.forRoute("wiki").kind, "orange")
        compare(Palette.forRoute("news").kind, "purple")
        compare(Palette.forRoute("beatmap").kind, "blue")
        compare(Palette.forRoute("wiki").body, Palette.forRoute("wiki").body)
        compare(Object.keys(Palette.forRoute("remote")).length, 0)
    }

    function test_escapePrecedence() {
        compare(Logic.escapeAction(true, true, true), "input")
        compare(Logic.escapeAction(false, true, true), "back")
        compare(Logic.escapeAction(false, false, true), "close")
        compare(Logic.escapeAction(false, false, false), "none")
    }
}
