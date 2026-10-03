import QtQuick
import QtTest
import "../../modules/bar/StartupBarRevealLogic.js" as StartupReveal

// The bar's startup arrival: it starts slid out and slides in once its widgets
// are staged. The rule lives in a shared JS module so this reads the same code
// TopBar.qml runs rather than restating it — the neighbouring
// tst_bar_reveal_motion.qml mirrors its logic instead, which is why a change to
// one can leave the other asserting something no longer true.
Item {
    id: root

    TestCase {
        name: "StartupBarReveal"
        when: windowShown

        // The product is the whole point: either mechanism holding at zero
        // collapses the bar. An `or`, a minimum or an average would let the two
        // half-cancel and park a bar in the middle of the screen.
        function test_eitherMechanismCollapsesTheBar() {
            compare(StartupReveal.slideProgress(1, 1), 1)
            compare(StartupReveal.slideProgress(1, 0), 0,
                    "an unexpanded bar must be collapsed even though auto-hide says shown")
            compare(StartupReveal.slideProgress(0, 1), 0,
                    "the auto-hide machine still owns collapsing in fullscreen")
            compare(StartupReveal.slideProgress(0, 0), 0)
        }

        // The slide is continuous, not a boolean: the bar arrives rather than
        // popping, so the progress has to survive the fractional middle.
        function test_theSlideIsContinuous() {
            compare(StartupReveal.slideProgress(1, 0.5), 0.5)
            compare(StartupReveal.slideProgress(0.5, 1), 0.5)
            compare(StartupReveal.slideProgress(0.5, 0.5), 0.25)
        }

        // An unclamped product lets a stray value push the offset past the
        // viewport, which slides the bar off the far side and hides it again —
        // the failure this clamp exists to prevent.
        function test_outOfRangeInputsAreClampedNotApplied() {
            compare(StartupReveal.slideProgress(1, 2), 1,
                    "overshoot must clamp to 1, not slide past the viewport")
            compare(StartupReveal.slideProgress(3, 1), 1)
            compare(StartupReveal.slideProgress(1, -1), 0,
                    "a negative must clamp to 0, not invert the slide")
            compare(StartupReveal.slideProgress(-2, -2), 0)
            compare(StartupReveal.slideProgress(undefined, 1), 0)
            compare(StartupReveal.slideProgress(1, NaN), 0)
        }

        // One-way: BarContent.startupReady drops back to false whenever staging
        // re-enters, and the first pointer event after login arrives right after
        // the slide. Neither may put the bar back off screen.
        function test_theStartupLatchIsOneWay() {
            verify(StartupReveal.latchStartup(true, false))
            verify(StartupReveal.latchStartup(false, true),
                   "an expanded bar stays expanded")
            compare(StartupReveal.latchStartup(false, false), false)
        }

        // While the bar has not arrived it is invisible but still overlaying the
        // screen edge, so it must not claim the full input region there.
        function test_theFullInputRegionWaitsForArrival() {
            verify(StartupReveal.claimsFullRegion(true, true))
            verify(!StartupReveal.claimsFullRegion(true, false),
                   "an unarrived bar must not claim the full input region")
            verify(!StartupReveal.claimsFullRegion(false, true),
                   "auto-hide still collapses the region in fullscreen")
            verify(!StartupReveal.claimsFullRegion(false, false))
        }
    }
}
