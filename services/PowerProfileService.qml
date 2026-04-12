pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Placeholder IPC handler for power profile cycling.
// Expand this service when implementing actual power profile management.
Singleton {
    id: root

    property string currentProfile: "balanced"

    IpcHandler {
        target: "powerProfile"

        function cycle() {
            const profiles = ["balanced", "performance", "power-saver"]
            const idx = profiles.indexOf(root.currentProfile)
            root.currentProfile = profiles[(idx + 1) % profiles.length]
        }
    }
}