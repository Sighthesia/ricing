import Quickshell
import QtQuick
import qs.modules.bar as BarParts

// Bare harness for isolating BarContextMenu teardown behavior.
ShellRoot {
    id: root

    Item {
        id: anchorHost
        width: 320
        height: 48
        visible: false
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    BarParts.BarContextMenu {
        id: menu
        anchorTarget: anchorHost
    }

    Component.onCompleted: {
        root._assert(menu !== null,
            "BarContextMenu should instantiate")
        console.log("BarContextMenuBare smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
