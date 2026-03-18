import Quickshell
import QtQuick
import qs.services

// Minimal harness to reproduce teardown behavior after touching mediaControl settings.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof SettingsService.data.mediaControl.enabled === "boolean",
            "mediaControl.enabled should exist")
        console.log("SettingsMediaBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
