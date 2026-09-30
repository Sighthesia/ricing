import QtQuick
import "./services" as Services

// Regression harness for the palette scheduler around a full-screen wallpaper
// reveal. It never starts the real color extraction command or writes a palette
// file; the process branch uses a short sleep as a disposable stand-in.
Item {
    id: root

    property int failures: 0
    property int checks: 0
    readonly property string testPath: "/tmp/afloat-color-service-reveal-gate.png"

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
        const service = Services.ColorService
        root.resetService(service)

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

    Component.onCompleted: Qt.callLater(root.run)
}
