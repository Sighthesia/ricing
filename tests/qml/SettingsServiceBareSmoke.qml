import Quickshell
import QtQuick
import qs.services

// Minimal harness to reproduce teardown behavior after touching SettingsService.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(SettingsService.data !== null,
            "SettingsService should expose data")
        console.log("SettingsServiceBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
