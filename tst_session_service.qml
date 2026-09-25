import QtQuick
import Quickshell
import "./services" as Services

ShellRoot {
    id: root

    property int checks: 0
    property int failures: 0
    property int lockRequests: 0

    function check(label, actual, expected) {
        checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        failures += 1
        console.log("FAIL:", label, "expected", JSON.stringify(expected),
                    "got", JSON.stringify(actual))
    }

    function runChecks() {
        const service = Services.SessionService
        service.lockRequested.connect(function() { root.lockRequests += 1 })

        check("lock action accepted", service.execute("lock"), true)
        check("lock action emits request", root.lockRequests, 1)
        check("lock action does not start process", service.running, false)
        check("lock action reports result", service.resultText, "Lock requested")
        check("unknown action rejected", service.execute("unknown"), false)

        console.log("Totals:", checks - failures, "passed,", failures, "failed")
        Qt.quit()
    }

    Component.onCompleted: Qt.callLater(root.runChecks)
}
