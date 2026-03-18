import Quickshell
import QtQuick
import qs.services

// Minimal harness to reproduce teardown behavior after touching systemMonitor settings.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof SettingsService.data.systemMonitor.enabled === "boolean",
            "systemMonitor.enabled should exist")
        console.log("SettingsSystemMonitorBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
