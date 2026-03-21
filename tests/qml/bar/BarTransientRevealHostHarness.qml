import Quickshell
import QtQuick
import "../../../services" as Services

Item {
    id: root

    required property var barLayoutService

    readonly property string mode:
        String(Quickshell.env("QS_BAR_TRANSIENT_REVEAL_MODE") || "all")

    function assertTrue(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function runRegistryMode() {
        root.barLayoutService.clearTransientExtension("tray")
        root.barLayoutService.clearTransientExtension("workspace")
        root.barLayoutService.setTransientExtension("tray", 10)
        root.barLayoutService.setTransientExtension("workspace", 18)

        assertTrue(root.barLayoutService.barTransientExtension === 18,
            "barTransientExtension should use the max registered height")

        root.barLayoutService.clearTransientExtension("workspace")
        assertTrue(root.barLayoutService.barTransientExtension === 10,
            "clearing one owner should expose the next registered height")

        root.barLayoutService.clearTransientExtension("tray")
        assertTrue(root.barLayoutService.barTransientExtension === 0,
            "clearing all owners should drop the aggregate extension to zero")
    }

    Component.onCompleted: {
        if (mode === "registry" || mode === "all")
            runRegistryMode()
        Qt.quit()
    }
}
