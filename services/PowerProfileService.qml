pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Cycles the currently exposed shell power mode.
Singleton {
    id: root

    readonly property string currentProfile:
        SettingsService.data.power.powerSaveEnabled ? "power-saver" : "balanced"

    IpcHandler {
        target: "powerProfile"

        function cycle() {
            SettingsService.data.power.powerSaveEnabled = !SettingsService.data.power.powerSaveEnabled
            SettingsService.save()
        }
    }
}
