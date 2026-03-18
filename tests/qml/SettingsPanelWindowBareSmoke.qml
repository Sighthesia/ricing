import Quickshell
import QtQuick
import qs.modules.bar as BarParts

// Bare harness for isolating SettingsPanelWindow teardown behavior.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    BarParts.SettingsPanelWindow {
        id: panel
    }

    Component.onCompleted: {
        root._assert(panel !== null,
            "SettingsPanelWindow should instantiate")
        console.log("SettingsPanelWindowBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
