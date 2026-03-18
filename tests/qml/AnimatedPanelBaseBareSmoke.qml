import Quickshell
import QtQuick
import qs.modules.bar as BarParts

// Bare harness for isolating AnimatedPanelBase teardown behavior.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    BarParts.AnimatedPanelBase {
        id: panel
        visible: false
    }

    Component.onCompleted: {
        root._assert(panel.exclusionMode !== undefined,
            "AnimatedPanelBase should instantiate")
        console.log("AnimatedPanelBaseBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
