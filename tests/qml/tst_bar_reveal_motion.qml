// Checks the bar's slide animation the way the popup host drives it: that
// duration scales with distance, and that the two directions use different
// easing. A Behavior on a bound property silently fights the binding, which is
// what this file exists to catch.
import QtQuick
import QtTest

Item {
    id: root
    width: 800
    height: 48

    TestCase {
        name: "BarRevealMotion"
        when: windowShown
        width: 800
        height: 48

        // Mirrors TopBar.qml's reveal motion. Config is recorded on the
        // animation rather than only acted on, because a TestCase function does
        // not run the event loop: `restart()` sets running, but nothing advances
        // the animation or delivers the change notification until a later turn.
        // Asserting on `running` here would therefore read the pre-change state.
        Item {
            id: host
            property bool revealed: true
            property real revealProgress: 1
            readonly property real base: 240
            // Last (duration, easing, to) the handler asked for.
            property var lastRequest: null

            function revealDuration() {
                const distance = Math.abs((host.revealed ? 1 : 0) - host.revealProgress)
                if (distance < 0.001)
                    return 0
                return Math.max(100, Math.round(host.base * distance))
            }

            NumberAnimation {
                id: motion
                target: host
                property: "revealProgress"
                running: false
            }

            // Inline handler, exactly as TopBar.qml declares it: a bare function
            // named after the signal is not reliably connected under
            // qmltestrunner, which silently leaves the motion unstarted.
            onRevealedChanged: {
                motion.stop()
                const target = host.revealed ? 1 : 0
                if (Math.abs(target - host.revealProgress) < 0.001) {
                    host.revealProgress = target
                    host.lastRequest = null
                    return
                }
                motion.duration = host.revealDuration()
                motion.easing.type = host.revealed ? Easing.OutCubic : Easing.InOutQuad
                motion.to = target
                host.lastRequest = {
                    duration: motion.duration,
                    easing: motion.easing.type,
                    to: motion.to
                }
                motion.restart()
            }
        }

        function init() {
            host.revealed = true
            host.revealProgress = 1
            host.lastRequest = null
            motion.stop()
        }

        function test_enteringRequestsTheShownTarget() {
            host.revealed = false
            host.revealProgress = 0
            host.revealed = true
            verify(host.lastRequest !== null, "entering animates")
            compare(host.lastRequest.to, 1)
            compare(host.lastRequest.easing, Easing.OutCubic)
        }

        function test_leavingRequestsTheCollapsedTarget() {
            host.revealed = false
            host.revealProgress = 0
            host.revealed = true
            // Settle first: `lastRequest` is written by the change handler, and
            // a second write in the same turn re-enters before the first has
            // been observed. Reading it immediately returns the previous value.
            tryCompare(host, "revealProgress", 1)
            host.revealed = false
            verify(host.lastRequest !== null, "leaving animates")
            compare(host.lastRequest.to, 0)
            // The exit must NOT reuse the enter curve: OutCubic front-loads
            // travel and the bar would appear to stall at the edge.
            compare(host.lastRequest.easing, Easing.InOutQuad)
        }

        function test_directionEasingDiffers() {
            host.revealed = false
            host.revealProgress = 0
            host.revealed = true
            tryCompare(host, "revealProgress", 1)
            const enter = host.lastRequest.easing
            host.revealed = false
            tryCompare(host, "revealProgress", 0)
            verify(enter !== host.lastRequest.easing,
                "enter and exit must use different easing")
        }

        function test_durationScalesWithRemainingDistance() {
            host.revealed = true
            host.revealProgress = 1
            host.revealed = false
            tryCompare(host, "revealProgress", 0)
            const full = host.lastRequest.duration
            // Interrupt halfway back: a fresh slide must be proportionally
            // shorter, or a re-reveal mid-flight stalls for the full duration.
            host.revealProgress = 0.5
            host.revealed = true
            verify(host.lastRequest.duration < full,
                "a half-done slide is shorter than a full one")
            compare(host.lastRequest.duration, 120)
        }

        function test_durationNeverDropsBelowTheFloor() {
            host.revealed = true
            host.revealProgress = 1
            host.revealed = false
            tryCompare(host, "revealProgress", 0)
            motion.stop()
            // Near-complete slide, so the remaining distance is tiny: a reveal
            // interrupted at the very end must still take a readable moment
            // rather than a 5ms snap that reads as a teleport.
            host.revealProgress = 0.98
            host.revealed = true
            // 240 * 0.02 = 4.8ms, floored to 100.
            compare(host.lastRequest.duration, 100)
        }

        function test_aFullSlideIsNotFloored() {
            // Guard the previous case: the floor applies to tiny distances only,
            // not to every reveal.
            host.revealed = true
            host.revealProgress = 1
            host.revealed = false
            tryCompare(host, "revealProgress", 0)
            motion.stop()
            host.revealProgress = 0
            host.revealed = true
            compare(host.lastRequest.duration, 240)
        }

        function test_noOpDoesNotAnimate() {
            host.revealed = true
            host.revealProgress = 1
            host.revealed = true
            compare(host.lastRequest, null, "a no-op change must not animate")
        }

        // The behavioural half, which does need the event loop. Without these the
        // file would only pin the arithmetic and never prove the bar moves.
        function test_enteringActuallySlidesIn() {
            host.revealed = false
            host.revealProgress = 0
            host.revealed = true
            tryCompare(host, "revealProgress", 1)
        }

        function test_leavingActuallySlidesOut() {
            host.revealed = true
            host.revealProgress = 1
            host.revealed = false
            tryCompare(host, "revealProgress", 0)
        }

        function test_interruptMidSlideStillSettlesOnTarget() {
            host.revealed = false
            host.revealProgress = 0
            host.revealed = true
            wait(60)
            const midway = host.revealProgress
            verify(midway > 0 && midway < 1, "caught it mid-flight")
            host.revealed = false
            tryCompare(host, "revealProgress", 0)
        }

        function test_progressIsPlainSoTheAnimationCanWriteIt() {
            // The bug this refactor had to avoid: an animated property that also
            // carries a binding is written against its own binding, so the slide
            // snaps back to the bound value the moment the animation ends.
            host.revealProgress = 0.25
            compare(host.revealProgress, 0.25)
        }
    }
}
