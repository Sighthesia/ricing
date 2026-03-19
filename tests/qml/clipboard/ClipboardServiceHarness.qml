import Quickshell
import QtQuick
import qs.services

// Regression harness for the clipboard history watcher.
Item {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: _checkTimer.restart()

    Timer {
        id: _checkTimer
        interval: 100
        repeat: false
        onTriggered: {
            root._assert(ClipboardService.watcherStarted,
                "clipboard watcher should start with the shell")
            Qt.quit()
        }
    }
}