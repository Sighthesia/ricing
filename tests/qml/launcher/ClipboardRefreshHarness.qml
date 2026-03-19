import Quickshell
import QtQuick
import qs.modules.launcher
import qs.services

// Regression harness for clipboard results refreshing after history arrives.
Item {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    LauncherCore {
        id: core
    }

    Component.onCompleted: _startTimer.restart()

    Timer {
        id: _startTimer
        interval: 50
        repeat: false
        onTriggered: {
            LauncherService.isOpen = true
            core._searchHeader.text = ">clip "
            core._refreshResults()

            ClipboardService.items = [{
                id: "1",
                preview: "direct-launch-clipboard",
                isImage: false
            }]
            ClipboardService.revision++
            _assertTimer.restart()
        }
    }

    Timer {
        id: _assertTimer
        interval: 100
        repeat: false
        onTriggered: {
            root._assert(core._resultData.length > 0,
                "clipboard results should refresh after history arrives")
            Qt.quit()
        }
    }
}