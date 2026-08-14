import QtQuick
import Quickshell.Io

// Read Linux uptime through Quickshell's native file API.
QtObject {
    id: root
    signal loaded(string text)
    function reload() { uptimeFile.reload() }

    property FileView uptimeFile: FileView {
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.loaded(text())
        onLoadFailed: root.loaded("")
    }
}
