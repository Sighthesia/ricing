import QtQuick
import Quickshell
import Quickshell.Io
import "./services" as Services

// Regression harness for the palette scheduler around a full-screen wallpaper
// reveal and for the startup quiet gate in front of it. It never starts the real
// color extraction command or writes a palette file; the process branch uses a
// short sleep as a disposable stand-in.
Item {
    id: root

    property int failures: 0
    property int checks: 0
    property string serviceSource: ""
    property bool sourceLoaded: false
    property bool started: false
    readonly property string testPath: "/tmp/afloat-color-service-reveal-gate.png"
    // Startup-gate fixtures. Three distinct paths so "keeps only the newest" is
    // observable, and none of them exists, so no command here can do real work.
    readonly property string gatePathA: "/tmp/afloat-color-service-gate-a.png"
    readonly property string gatePathB: "/tmp/afloat-color-service-gate-b.png"
    readonly property string gatePathC: "/tmp/afloat-color-service-gate-c.png"

    // The service's own text, for the one fact behaviour cannot reach:
    // resetService() normalises the startup flag before every run, so a flipped
    // default inside the service would start extraction on the locked floor and
    // every behavioural check below would still be green.
    FileView {
        id: sourceView
        // Absolute, because a root harness' own location is not what FileView
        // resolves against; the runner always starts from the repo root.
        path: (Quickshell.env("PWD") || ".") + "/services/ColorService.qml"
        blockLoading: true
        watchChanges: false
        onLoaded: {
            root.serviceSource = sourceView.text()
            root.sourceLoaded = true
            root.run()
        }
        onLoadFailed: error => {
            console.log("FAIL: read services/ColorService.qml |", error)
            root.failures++
            Qt.quit()
        }
    }

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    function resetService(service) {
        service._debounce.stop()
        service._holdTimer.stop()
        if (service._proc.running)
            service._proc.running = false
        service._pendingPath = ""
        service._heldPath = ""
        service._runningPath = ""
        service._processStopRequested = false
        service._revealInFlight = false
        // Start every run with the startup gate closed, which is how the shell
        // finds this service.
        service._startupQuiet = false
        service.isExtracting = false
        service.pendingScheme = ""
    }

    function finish() {
        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    // Drive the service through a reveal start, a deferred request, and reveal
    // completion. The first assertion is intentionally red before the fix:
    // revealStarted() must cancel a debounce that was already armed.
    function run() {
        // Both entry points may arrive (the blocking read finishes during
        // construction, the deferred call one turn later); the latch makes the
        // run happen exactly once, and an unreadable file fails loudly instead of
        // reporting a green run against an empty string.
        if (root.started || !root.sourceLoaded)
            return
        root.started = true
        if (root.serviceSource.length < 500) {
            console.log("FAIL: services/ColorService.qml was not readable |",
                        root.serviceSource.length, "chars")
            Qt.quit()
            return
        }

        const service = Services.ColorService
        root.resetService(service)

        root.checkStartupQuietGate(service)

        service._pendingPath = root.testPath
        service._debounce.interval = 1000
        service._debounce.restart()
        service.revealStarted()

        root.check("reveal marks palette work in flight",
                   service._revealInFlight === true)
        root.check("reveal cancels an armed extraction debounce",
                   service._debounce.running === false)

        service.extractColors(root.testPath)
        root.check("wallpaper request is held during reveal",
                   service._heldPath === root.testPath)
        root.check("held request does not arm a second debounce",
                   service._debounce.running === false)

        service.revealCompleted()
        root.check("reveal releases the palette gate",
                   service._revealInFlight === false)
        root.check("held request resumes after reveal",
                   service._debounce.running === true)

        // Also cover the startup race where extraction already owns a process
        // by the time the asynchronously decoded wallpaper can start its mask.
        service._debounce.stop()
        service._pendingPath = ""
        service._heldPath = ""
        service._runningPath = root.testPath
        // Process command changes and starts are separated by one event-loop
        // turn so the probe observes the command that was just assigned.
        Qt.callLater(function() {
            service._proc.command = ["sh", "-c", "sleep 2"]
            Qt.callLater(function() { service._proc.running = true })
        })
        processProbe.restart()
    }

    // The startup quiet gate, in front of the reveal gate. Palette extraction is a
    // ~1.6s CPU-bound job and the startup window is exactly where that cost is
    // visible, so before the shell opens the gate a request may only be recorded.
    // Everything here goes through the service's own API — no internal is written
    // except the one reset below, which exists to reach the second branch of
    // startupQuietReady().
    //
    // A regression that throws instead of gating would abort run() before the
    // harness ever quits, turning a named failure into a timeout, so the group
    // reports the exception and lets the rest of the run continue.
    function checkStartupQuietGate(service) {
        try {
            root.checkStartupQuietGateBody(service)
        } catch (error) {
            root.check("the palette startup gate ran without an exception", false,
                       "" + error)
            service._startupQuiet = true
        }
    }

    function checkStartupQuietGateBody(service) {
        // The production default, read from source: resetService() normalises the
        // flag, so nothing behavioural here can tell a closed gate from a flipped
        // default — and a default of true starts the job on the locked floor.
        root.check("the palette startup gate is closed by default",
                   root.serviceSource.indexOf("property bool _startupQuiet: false") >= 0)
        root.check("the palette startup gate starts closed",
                   service._startupQuiet === false)

        service.extractColors(root.gatePathA)
        root.check("a closed palette gate arms no debounce",
                   service._debounce.running === false)
        root.check("a closed palette gate starts no extraction",
                   service.isExtracting === false)

        // Only the newest request survives a closed gate: two requests in one
        // startup window must cost one later run, not two.
        service.extractColors(root.gatePathB)
        root.check("a closed palette gate keeps only the newest request",
                   service._pendingPath === root.gatePathB)

        // A reveal inside the startup window parks the request in the held slot,
        // and its completion must not leak a run either — that flush is the one
        // path that would otherwise start work behind a closed gate.
        service.revealStarted()
        root.check("a startup reveal holds the newest request",
                   service._heldPath === root.gatePathB)
        service.revealCompleted()
        root.check("a reveal that ends before quiet-ready starts nothing",
                   service._debounce.running === false
                   && service._pendingPath === root.gatePathB)

        // Opening the gate flushes exactly one debounced attempt, for the newest
        // path, through the existing debounce.
        service.startupQuietReady()
        root.check("opening the palette gate arms one debounced attempt",
                   service._startupQuiet === true
                   && service._debounce.running === true
                   && service._pendingPath === root.gatePathB)

        // One-way: a duplicated startup report cannot arm a second run.
        service._debounce.stop()
        service.startupQuietReady()
        root.check("the palette gate opens only once",
                   service._debounce.running === false)

        // Nothing pending at open time — a session already on a cached palette
        // has nothing to flush, and the gate must not invent work. Reached by
        // rewinding the flag, since the branch above already opened it.
        service._startupQuiet = false
        service._pendingPath = ""
        service.startupQuietReady()
        root.check("opening the palette gate with nothing pending arms nothing",
                   service._startupQuiet === true
                   && service._debounce.running === false)

        // After the gate the live path is untouched: an ordinary wallpaper switch
        // arms extraction exactly as it did before the gate existed.
        service.extractColors(root.gatePathC, 40)
        root.check("an open palette gate arms extraction as before",
                   service._debounce.running === true)
        service._debounce.stop()
        service._pendingPath = ""
    }

    function checkRunningProcess() {
        const service = Services.ColorService
        if (!service._proc.running) {
            processProbe.restart()
            return
        }
        root.check("extraction process starts for the interruption probe",
                   service._proc.running === true)
        service.revealStarted()
        root.check("reveal records an asynchronous process stop",
                   service._processStopRequested === true)
        service.revealCompleted()
        root.check("completion queues work while the old process drains",
                   service._debounce.running === true)
        stopProbe.restart()
    }

    function finishRunningProcessProbe() {
        const service = Services.ColorService
        if (service._proc.running) {
            stopProbe.restart()
            return
        }
        root.check("reveal stops an active extraction process",
                   service._proc.running === false)
        root.check("process stop state clears on exit",
                   service._processStopRequested === false)
        root.check("interrupted process path is retained",
                   service._pendingPath === root.testPath)
        root.check("interrupted process path resumes after reveal",
                   service._debounce.running === true)

        root.resetService(service)
        root.finish()
    }

    Timer {
        id: processProbe
        interval: 40
        repeat: false
        onTriggered: root.checkRunningProcess()
    }

    Timer {
        id: stopProbe
        interval: 40
        repeat: false
        onTriggered: root.finishRunningProcessProbe()
    }

    // One turn after construction, so every Timer below exists before the first
    // check runs. blockLoading makes the source read finish first, so this call is
    // usually the no-op that the latch turns into a skip.
    Component.onCompleted: Qt.callLater(root.run)
}
