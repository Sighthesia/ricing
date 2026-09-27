import QtQuick
import QtTest
import "../../modules/lazerbar/WallpaperBootLogic.js" as Boot

// Contract for the wallpaper-first boot gate: a screen is keyed by identity
// plus geometry, completion is recorded per key, and every currently present
// screen must report finished before the boot reveal is allowed to start.
Item {
    TestCase {
        name: "WallpaperBoot"
        when: windowShown
        visible: true

        function screens() {
            return [
                { name: "DP-1", x: 0, y: 0, width: 1920, height: 1080 },
                { name: "HDMI-1", x: 1920, y: 0, width: 1920, height: 1080 },
            ]
        }

        function test_keyIncludesGeometry() {
            compare(Boot.screenKey("DP-1", 0, 0, 1920, 1080),
                    "DP-1@0,0,1920x1080")
            verify(Boot.screenKey("DP-1", 0, 0, 1920, 1080)
                   !== Boot.screenKey("DP-1", 0, 0, 2560, 1440))
        }

        function test_currentKeysAreStable() {
            compare(Boot.currentKeys(screens()), [
                "DP-1@0,0,1920x1080",
                "HDMI-1@1920,0,1920x1080",
            ])
        }

        function test_duplicateCompletionIsIgnored() {
            var key = Boot.screenKey("DP-1", 0, 0, 1920, 1080)
            var once = Boot.markFinished([], key)
            var twice = Boot.markFinished(once, key)
            compare(once, [key])
            compare(twice, [key])
        }

        function test_allScreensMustFinish() {
            var keys = Boot.currentKeys(screens())
            var first = Boot.markFinished([], keys[0])
            verify(!Boot.isReady(first, keys))
            var second = Boot.markFinished(first, keys[1])
            verify(Boot.isReady(second, keys))
        }

        function test_removedScreenDoesNotBlock() {
            var keys = Boot.currentKeys(screens())
            var finished = Boot.markFinished([], keys[0])
            compare(Boot.currentKeys([screens()[0]]), [keys[0]])
            verify(Boot.isReady(finished, Boot.currentKeys([screens()[0]])))
        }

        function test_addedScreenBlocksUntilFinished() {
            var original = screens()
            var originalKeys = Boot.currentKeys(original)
            var finished = Boot.markFinished([], originalKeys[0])
            finished = Boot.markFinished(finished, originalKeys[1])
            var added = original.concat([
                { name: "DP-2", x: 0, y: 1080, width: 1920, height: 1080 },
            ])
            var addedKeys = Boot.currentKeys(added)
            verify(!Boot.isReady(finished, addedKeys))
            finished = Boot.markFinished(finished, addedKeys[2])
            verify(Boot.isReady(finished, addedKeys))
        }

        function test_resizedScreenBlocksUntilItReportsAgain() {
            var original = screens()
            var keys = Boot.currentKeys(original)
            var finished = Boot.markFinished([], keys[0])
            finished = Boot.markFinished(finished, keys[1])
            verify(Boot.isReady(finished, keys))
            // A resolution change re-keys the first screen, so the completion
            // recorded for its old geometry no longer counts and the shell
            // blocks again.
            var resized = [
                { name: "DP-1", x: 0, y: 0, width: 2560, height: 1440 },
                original[1],
            ]
            var resizedKeys = Boot.currentKeys(resized)
            verify(!Boot.isReady(finished, resizedKeys))
            // Reporting the new geometry is what the re-keyed screen does, and
            // it must be enough to unblock without the other screen reporting
            // a second time.
            verify(Boot.isReady(Boot.markFinished(finished, resizedKeys[0]), resizedKeys))
        }

        function test_emptyScreensAreNotReady() {
            verify(!Boot.isReady([], []))
        }

        function test_aChangedWallpaperAlwaysReveals() {
            compare(Boot.bootOutcome("/tmp/new.png", "/tmp/old.png", false, false), "reveal")
            compare(Boot.bootOutcome("/tmp/new.png", "", false, false), "reveal")
        }

        function test_emptyPathCompletesWithoutAReveal() {
            compare(Boot.bootOutcome("", "", false, false), "empty")
            // The order is the contract: nothing below may promote an empty
            // request into a reveal or any other outcome.
            compare(Boot.bootOutcome("", "", true, false), "empty")
            compare(Boot.bootOutcome("", "/tmp/old.png", false, true), "empty")
            compare(Boot.bootOutcome("", "/tmp/old.png", true, true), "empty")
        }

        function test_imageErrorCompletesWithoutAReveal() {
            compare(Boot.bootOutcome("/tmp/broken.png", "", true, false), "error")
            compare(Boot.bootOutcome("/tmp/broken.png", "/tmp/broken.png", true, false), "error")
            // An error outranks reduced motion: the image is gone either way.
            compare(Boot.bootOutcome("/tmp/broken.png", "", true, true), "error")
        }

        function test_reducedMotionCompletesWithoutAReveal() {
            compare(Boot.bootOutcome("/tmp/new.png", "", false, true), "reduced-motion")
            // Reduced motion is reached with the image decoded but before the
            // unchanged-source check, so it wins over "nothing to do".
            compare(Boot.bootOutcome("/tmp/new.png", "/tmp/new.png", false, true),
                    "reduced-motion")
        }

        function test_unchangedSourceCompletesWithoutAReveal() {
            compare(Boot.bootOutcome("/tmp/same.png", "/tmp/same.png", false, false),
                    "unchanged")
        }

        function test_everyOutcomeIsReachableExactlyOnce() {
            var seen = {}
            var requests = [
                ["", "", false, false],
                ["/tmp/broken.png", "", true, false],
                ["/tmp/new.png", "", false, true],
                ["/tmp/same.png", "/tmp/same.png", false, false],
                ["/tmp/new.png", "/tmp/old.png", false, false],
            ]
            for (var index = 0; index < requests.length; index++) {
                var outcome = Boot.bootOutcome(requests[index][0], requests[index][1],
                                               requests[index][2], requests[index][3])
                verify(!(outcome in seen), "outcome " + outcome + " was reached twice")
                seen[outcome] = true
            }
            // No sixth outcome: a caller can exhaustively switch on this result.
            compare(Object.keys(seen).sort(), [
                "empty", "error", "reduced-motion", "reveal", "unchanged",
            ])
        }

        function test_nonRevealOutcomesStillCompleteTheScreen() {
            // Each non-reveal outcome, built through the classifier rather than
            // spelled out, completes its screen on the spot: the shell must not
            // wait on a reveal that will never run.
            var keys = Boot.currentKeys(screens())
            var requests = [
                ["", "/tmp/old.png", false, false],
                ["/tmp/broken.png", "/tmp/old.png", true, false],
                ["/tmp/new.png", "/tmp/old.png", false, true],
                ["/tmp/same.png", "/tmp/same.png", false, false],
            ]
            for (var index = 0; index < requests.length; index++) {
                var outcome = Boot.bootOutcome(requests[index][0], requests[index][1],
                                               requests[index][2], requests[index][3])
                verify(Boot.bootOutcomeCompletesImmediately(outcome),
                       outcome + " must complete without an animation")
                // Each outcome stands in for one screen's whole boot, so the
                // outcome decides both the timing and the readiness that follows.
                var key = keys[index % keys.length]
                var finished = Boot.markFinished([], key)
                verify(Boot.isReady(finished, [key]),
                       outcome + " must mark screen " + key + " ready")
            }
        }

        function test_revealOutcomeWaitsForItsAnimation() {
            // A real reveal owes the shell an animation, so it is not an immediate
            // completion and its screen stays unreported until the reveal settles.
            var outcome = Boot.bootOutcome("/tmp/new.png", "/tmp/old.png", false, false)
            compare(outcome, "reveal")
            verify(!Boot.bootOutcomeCompletesImmediately(outcome))
            var keys = Boot.currentKeys(screens())
            verify(!Boot.isReady([], [keys[0]]))
        }

        function test_unknownOutcomesAreNotImmediateCompletions() {
            // The seam is fail-closed: a string the classifier cannot produce must
            // never be read as "settle now and report".
            verify(!Boot.bootOutcomeCompletesImmediately("reveal"))
            verify(!Boot.bootOutcomeCompletesImmediately(""))
            verify(!Boot.bootOutcomeCompletesImmediately("unknown"))
            verify(!Boot.bootOutcomeCompletesImmediately(undefined))
        }
    }
}
