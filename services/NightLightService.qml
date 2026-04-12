pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Placeholder IPC handler for night light toggle.
// Expand this service when implementing actual night light / color temperature features.
Singleton {
    id: root

    property bool enabled: false

    IpcHandler {
        target: "nightLight"

        function toggle() { root.enabled = !root.enabled }
    }
}