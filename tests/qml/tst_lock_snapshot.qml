import QtQuick
import QtTest
import "../../modules/lock"

// A request with no capture provider — the session-start lock — has nothing to
// wait for. The lock surface keeps its themed floor instead of a screenshot, so
// committing in the same turn is what lets the session lock take the screen
// immediately rather than after a fallback window in which the desktop that the
// lock is about to replace is still fully visible.
Item {
    id: root
    width: 320
    height: 240

    // Whether the stand-in provider below reports its screens. QML calls the
    // provider as a plain function, so `this` is not the snapshot; the flag is
    // read from the root instead.
    property bool reportNow: false

    // Each test builds its own snapshot, so no state carries between functions.
    Component {
        id: captureless

        LockSnapshot {
            fallbackIntervalMs: 2000
        }
    }

    // A provider that reports nothing, standing in for a silent grim capture.
    Component {
        id: silent

        LockSnapshot {
            fallbackIntervalMs: 120
            snapshotProvider: function (screen, screenCount, generation, report) {
                if (!root.reportNow)
                    return { ready: false }
                for (var index = 0; index < screenCount; ++index)
                    report(index, "file:///shot-" + index + ".jpg")
                return { ready: false }
            }
        }
    }

    TestCase {
        name: "LockSnapshot"
        when: windowShown

        function init() {
            root.reportNow = false
        }

        function newCaptureless() {
            return createTemporaryObject(captureless, root)
        }

        function newSilent(reportNow) {
            var snapshot = createTemporaryObject(silent, root)
            root.reportNow = reportNow === true
            return snapshot
        }

        // The regression: a captureless request used to sit on the fallback
        // timer, leaving the half-built startup desktop on screen for the whole
        // grace window before the lock surface appeared.
        function test_requestWithoutAProviderIsReadyImmediately() {
            var snapshot = newCaptureless()
            verify(snapshot !== null)
            compare(snapshot.ready, false, "nothing requested yet")
            snapshot.request(2)
            compare(snapshot.ready, true, "nothing to prepare, so commit at once")
            compare(snapshot.generation, 1)
            compare(snapshot.snapshotUrlFor(0), "", "no capture to hand out")
            compare(snapshot.snapshotUrlFor(1), "")
        }

        function test_capturelessRequestReportsItsOwnGeneration() {
            var snapshot = newCaptureless()
            var reported = -1
            snapshot.prepared.connect(function (generation) { reported = generation })
            snapshot.request(1)
            compare(reported, 1, "the report carries the request generation")
        }

        function test_zeroScreenCapturelessRequestStillCompletes() {
            var snapshot = newCaptureless()
            snapshot.request(0)
            compare(snapshot.ready, true)
        }

        function test_providerRequestWaitsForItsFallback() {
            var snapshot = newSilent(false)
            snapshot.request(2)
            compare(snapshot.ready, false, "a silent provider must not resolve on its own")
            tryCompare(snapshot, "ready", true)
            compare(snapshot.snapshotUrlFor(0), "", "the fallback resolves to no capture")
        }

        function test_providerReportsFillTheirOwnSlots() {
            var snapshot = newSilent(true)
            snapshot.request(2)
            compare(snapshot.ready, true, "every screen reported in one turn")
            compare(snapshot.snapshotUrlFor(0), "file:///shot-0.jpg")
            compare(snapshot.snapshotUrlFor(1), "file:///shot-1.jpg")
            compare(snapshot.snapshotUrlFor(2), "", "no slot beyond the request")
            compare(snapshot.snapshotUrlFor(-1), "")
            compare(snapshot.snapshotUrlFor(0.5), "")
        }

        // A provider that reports from inside its own call and then returns a
        // result object: the returned object has no url, and it must not erase
        // the capture the provider already handed over for that screen.
        function test_returnedResultDoesNotEraseAnAlreadyReportedScreen() {
            var snapshot = newSilent(true)
            snapshot.request(1)
            compare(snapshot.snapshotUrlFor(0), "file:///shot-0.jpg")
        }

        // A new request invalidates the previous generation's urls, so a stale
        // capture can never show up under a later lock.
        function test_newRequestClearsPreviousUrls() {
            var snapshot = newSilent(true)
            snapshot.request(2)
            compare(snapshot.snapshotUrlFor(1), "file:///shot-1.jpg")

            root.reportNow = false
            snapshot.request(2)
            compare(snapshot.snapshotUrlFor(0), "", "the stale capture is dropped")
            compare(snapshot.snapshotUrlFor(1), "")
        }

        function test_duplicateReportsAreCountedOnce() {
            var snapshot = newCaptureless()
            var reports = 0
            snapshot.prepared.connect(function () { ++reports })
            snapshot.request(2)
            compare(reports, 1)
        }
    }
}
