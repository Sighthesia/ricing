import Quickshell
import QtQuick
import qs.modules.bar as BarParts

// Bare harness for isolating WidgetPickerWindow teardown behavior.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    BarParts.WidgetPickerWindow {
        id: panel
    }

    Component.onCompleted: {
        root._assert(panel !== null,
            "WidgetPickerWindow should instantiate")
        console.log("WidgetPickerWindowBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
