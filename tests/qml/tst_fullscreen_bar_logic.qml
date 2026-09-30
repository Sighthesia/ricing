import QtQuick
import QtTest
import "../../modules/bar/FullscreenBarLogic.js" as Logic

Item {
    TestCase {
        name: "FullscreenBarLogic"

        // state helper: a collapsed bar that is armed to be summoned by the edge.
        function hidden(overrides) {
            var state = {
                enabled: true,
                fullscreen: true,
                pinned: false,
                revealed: false,
                armed: true
            }
            for (var key in overrides || {})
                state[key] = overrides[key]
            return state
        }

        function apply(state, type, value, distance) {
            return Logic.reduce(state, { type: type, value: value, distance: distance })
        }

        function test_defaultsToVisible() {
            var state = Logic.initialState()
            compare(state.revealed, true)
            compare(state.fullscreen, false)
        }

        function test_enteringFullscreenCollapses() {
            var state = apply(Logic.initialState(), "fullscreen", true)
            compare(state.revealed, false)
            // Disarmed: the pointer may still be sitting on the new strip.
            compare(state.armed, false)
        }

        function test_leavingFullscreenReveals() {
            var state = apply(hidden(), "fullscreen", false)
            compare(state.revealed, true)
            compare(state.armed, true)
        }

        function test_repeatedFullscreenEventIsIdempotent() {
            var once = apply(Logic.initialState(), "fullscreen", true)
            var twice = apply(once, "fullscreen", true)
            compare(twice.revealed, once.revealed)
            compare(twice.armed, once.armed)
        }

        // The regression: a bar that collapsed once could not collapse again.
        // Once hidden, `fullscreen` is already true, so an early return on an
        // unchanged value silently turned every later fullscreen into a no-op.
        function test_fullscreenCollapsesAgainAfterTheBarIsAlreadyHidden() {
            // Collapse on the first fullscreen.
            var state = apply(Logic.initialState(), "fullscreen", true)
            compare(state.revealed, false)
            // A first collapse disarms, so recall takes the real two-step: the
            // pointer travels off the strip, then back onto it.
            state = apply(state, "move", undefined, 24)
            state = apply(state, "enter")
            compare(state.revealed, true)
            // Then it collapses again on the idle timer, with fullscreen never
            // having toggled back to false in between.
            state = apply(state, "leave")
            compare(state.revealed, false)
            compare(state.fullscreen, true)
            // Fullscreen never toggled, so the edge is not re-crossed. The bar
            // must still collapse when the event is re-sent.
            state = apply(state, "enter")
            compare(state.revealed, true)
            state = apply(state, "fullscreen", true)
            compare(state.revealed, false)
        }

        function test_fullscreenWhileHiddenStaysCollapsed() {
            // Re-sending `fullscreen` true must not half-restore the bar.
            var hiddenOnce = apply(Logic.initialState(), "fullscreen", true)
            var again = apply(hiddenOnce, "fullscreen", true)
            compare(again.revealed, false)
            compare(again.armed, false)
        }

        function test_enterRevealsAndDisarms() {
            var state = apply(hidden(), "enter")
            compare(state.revealed, true)
            // The reveal consumed the arm, so a pointer parked on the strip
            // cannot flap the bar when the idle timer collapses it again.
            compare(state.armed, false)
        }

        function test_enterWithoutArmDoesNotFlap() {
            var state = apply(hidden({ armed: false }), "enter")
            compare(state.revealed, false)
        }

        function test_leaveCollapsesAndRearms() {
            var state = apply(hidden({ revealed: true }), "leave")
            compare(state.revealed, false)
            compare(state.armed, true)
        }

        function test_leaveWhileNotFullscreenKeepsBarVisible() {
            var state = apply(Logic.initialState(), "leave")
            compare(state.revealed, true)
        }

        function test_idleCollapsesWithoutRearming() {
            var state = apply(hidden({ revealed: true, armed: true }), "idle")
            compare(state.revealed, false)
            compare(state.armed, false)
        }

        function test_idleWhilePinnedKeepsBarVisible() {
            var state = apply(hidden({ revealed: true, pinned: true }), "idle")
            compare(state.revealed, true)
        }

        function test_pinnedForcesVisible() {
            var state = apply(hidden(), "pinned", true)
            compare(state.revealed, true)
            compare(state.armed, true)
        }

        function test_unpinningWhileFullscreenDoesNotRevealByItself() {
            var pinned = apply(hidden(), "pinned", true)
            var unpinned = apply(pinned, "pinned", false)
            compare(unpinned.revealed, true)
            compare(unpinned.armed, true)
        }

        function test_disablingAutoHideAlwaysShows() {
            var state = apply(hidden(), "enabled", false)
            compare(state.revealed, true)
        }

        function test_moveRearmsOnlyPastTheStrip() {
            var strip = Logic.revealStripHeight
            // Strictly past strip + slack: the boundary itself is still "on the
            // edge", so it must not re-arm and re-trigger a reveal.
            compare(apply(hidden({ armed: false }), "move", undefined, 0).armed, false)
            compare(apply(hidden({ armed: false }), "move", undefined, strip).armed, false)
            compare(apply(hidden({ armed: false }), "move", undefined, strip + 1).armed, false)
            compare(apply(hidden({ armed: false }), "move", undefined, strip + Logic.revealArmSlack).armed, false)
            compare(apply(hidden({ armed: false }), "move", undefined, strip + Logic.revealArmSlack + 1).armed, true)
        }

        function test_moveWithInvalidDistanceIsIgnored() {
            var state = apply(hidden({ armed: false }), "move", undefined, NaN)
            compare(state.armed, false)
        }

        function test_reduceNeverMutatesItsInput() {
            var state = hidden()
            var snapshot = JSON.stringify(state)
            apply(state, "enter")
            apply(state, "idle")
            apply(state, "fullscreen", false)
            compare(JSON.stringify(state), snapshot)
        }

        function test_reduceToleratesMissingStateAndEvent() {
            compare(Logic.reduce(null, null).revealed, true)
            compare(Logic.reduce(hidden(), null).revealed, false)
            compare(Logic.reduce(hidden(), { type: "nope" }).revealed, false)
        }

        function test_resetRestoresDefaults() {
            var state = apply(hidden({ pinned: true }), "reset")
            compare(state.revealed, true)
            compare(state.fullscreen, false)
            compare(state.pinned, false)
        }

        function test_distanceFromEdgeMeasuresFromTheAnchoredEdge() {
            // Top bar: y is already the distance from the top edge.
            compare(Logic.distanceFromEdge(0, 48, true), 0)
            compare(Logic.distanceFromEdge(20, 48, true), 20)
            // Bottom bar: measure up from the bar's own bottom edge.
            compare(Logic.distanceFromEdge(48, 48, false), 0)
            compare(Logic.distanceFromEdge(30, 48, false), 18)
            compare(Logic.distanceFromEdge(NaN, 48, true), Infinity)
        }

        function test_revealStripIsThin() {
            // The collapsed bar's input region must stay thin enough to read as
            // an edge hint rather than a second bar.
            compare(Logic.revealStripHeight, 3)
        }

        function test_idleDelayIsImmediateButTimerIntervalIsUsable() {
            // Leaving the bar already collapses it at once, so the idle fallback
            // must not add a perceptible wait on top of that.
            compare(Logic.idleHideDelay, 0)
            // A Timer with interval 0 spins once per event-loop turn instead of
            // firing once, so the tick handed to a Timer must stay positive.
            verify(Logic.minTimerInterval > 0)
        }

        // The behaviour the zero delay is there to produce: pointer motion never
        // leaves the bar waiting, whether it stays or leaves.
        function test_barCollapsesOnLeaveWithoutWaiting() {
            var revealed = apply(Logic.initialState(), "fullscreen", false)
            revealed = apply(hidden({ revealed: true, armed: false }), "enter")
            compare(revealed.revealed, true)
            // No idle event in between: leaving is enough on its own.
            var left = apply(revealed, "leave")
            compare(left.revealed, false)
        }

        // The collapse path must be able to summon the bar back without a
        // pointer-left event: collapsing shrinks the input region under the
        // pointer, and the compositor need not report the change.
        function test_rearmAfterCollapseArmsWhenPointerIsOffTheStrip() {
            var collapsed = hidden({ armed: false })
            var state = Logic.rearmAfterCollapse(collapsed, Logic.revealStripHeight + Logic.revealArmSlack + 4)
            compare(state.armed, true)
            compare(state.revealed, false)
        }

        function test_rearmAfterCollapseStaysDisarmedOnTheStrip() {
            var collapsed = hidden({ armed: false })
            // The pointer is parked on the strip itself: revealing now would
            // flap, so it must stay disarmed.
            compare(Logic.rearmAfterCollapse(collapsed, 1).armed, false)
            compare(Logic.rearmAfterCollapse(collapsed, Logic.revealStripHeight).armed, false)
        }

        function test_rearmAfterCollapseArmsWhenPointerPositionIsUnknown() {
            var collapsed = hidden({ armed: false })
            compare(Logic.rearmAfterCollapse(collapsed, -1).armed, true)
            compare(Logic.rearmAfterCollapse(collapsed, NaN).armed, true)
            compare(Logic.rearmAfterCollapse(collapsed, undefined).armed, true)
        }

        function test_rearmAfterCollapseNeverRevealsByItself() {
            var collapsed = hidden({ armed: false })
            // Arming is a licence for the NEXT edge hover, not a reveal.
            compare(Logic.rearmAfterCollapse(collapsed, 40).revealed, false)
        }

        function test_fullSessionStaysRecoverable() {
            // Walk the real sequence: collapse on fullscreen with the pointer
            // parked mid-bar, then the user moves to the edge and back out.
            var state = apply(Logic.initialState(), "fullscreen", true)
            compare(state.revealed, false)
            state = Logic.rearmAfterCollapse(state, 24)
            state = apply(state, "enter")
            compare(state.revealed, true)
            state = apply(state, "leave")
            compare(state.revealed, false)
            state = apply(state, "enter")
            compare(state.revealed, true)
        }

        function test_pinnedBarSurvivesFullscreen() {
            // The launcher pins the bar open, so entering fullscreen underneath
            // it must not collapse the bar out from under the overlay.
            var pinned = apply(Logic.initialState(), "pinned", true)
            var state = apply(pinned, "fullscreen", true)
            compare(state.revealed, true)
            // And once the overlay closes, the normal collapse path resumes.
            state = apply(state, "pinned", false)
            state = apply(state, "idle")
            compare(state.revealed, false)
        }
    }
}
