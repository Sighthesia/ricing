import QtQuick
import QtTest
import "../../modules/lazerbar/WaveSurfaceLogic.js" as Logic

// Verify the pure route validation, geometry, and keyboard contracts without Quickshell.
TestCase {
    name: "WaveSurfaceLogic"

    function test_routesAndToggle() {
        compare(Logic.normalizeRoute("launcher"), "launcher")
        compare(Logic.normalizeRoute("settings"), "")
        compare(Logic.normalizeRoute("music"), "")
        compare(Logic.normalizeRoute(""), "")
        compare(Logic.normalizeRoute(null), "")
        // Content routes stay outside the generic shell's validation.
        compare(Logic.normalizeRoute("wiki"), "")
        compare(Logic.normalizeRoute("news"), "")
        compare(Logic.normalizeRoute("beatmap"), "")
        compare(Logic.toggleRoute("", "launcher"), "launcher")
        compare(Logic.toggleRoute("launcher", "launcher"), "")
        compare(Logic.toggleRoute("", "bogus"), "")
    }

    // The control center is a VIEW inside the launcher page, so it is not a
    // route and this is the assertion that keeps it from quietly becoming one
    // again. A route name that survives normalization is one the host will
    // accept from openRoute(), mount its own retained Loader component for, and
    // hand a second header/rail contract to - so a view that re-registered itself
    // would rebuild all of that on top of the page that already hosts it.
    function test_theControlCenterIsNotARoute() {
        compare(Logic.routes.indexOf("control-center"), -1,
            "the wave has one route; the control center is a view inside it")
        verify(!Logic.isRoute("control-center"))
        compare(Logic.normalizeRoute("control-center"), "",
            "an unregistered route must not resolve")
        // And the toggle must not smuggle it past validation either: asking for
        // the control center has to leave the current route standing, not select
        // something the host would then have to mount.
        compare(Logic.toggleRoute("launcher", "control-center"), "launcher")
        compare(Logic.toggleRoute("", "control-center"), "")
    }

    function test_waveGeometry() {
        compare(Logic.surfaceWidth(1920), 1632)
        compare(Logic.surfaceWidth(800), 680)
        compare(Logic.surfaceWidth(-100), 0)
        compare(Logic.waveAngle(0), 13)
        compare(Logic.waveAngle(1), -7)
        compare(Logic.waveAngle(2), 4)
        compare(Logic.waveAngle(3), -2)
        compare(Logic.waveAngle(4), 0)
        compare(Logic.sidebarWidth(100), 176)
        compare(Logic.sidebarWidth(400), 280)
        compare(Logic.clamp(Number.NaN, 2, 5), 2)
    }

    function test_escapePrecedence() {
        compare(Logic.escapeAction(true, true, true), "input")
        compare(Logic.escapeAction(false, true, true), "back")
        compare(Logic.escapeAction(false, false, true), "close")
        compare(Logic.escapeAction(false, false, false), "none")
    }

    // Keep last: registering a route mutates shared library state for this engine.
    function test_futureRouteExtension() {
        verify(!Logic.isRoute("gallery"))
        verify(Logic.registerRoute("gallery"))
        compare(Logic.normalizeRoute("gallery"), "gallery")
        verify(!Logic.registerRoute("gallery"))
        verify(!Logic.registerRoute(""))
        verify(!Logic.isRoute("galleryx"))
    }
}
