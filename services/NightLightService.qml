pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Maps the legacy night-light shortcut onto DymicShell's dark/light appearance mode.
Singleton {
    id: root

    readonly property bool enabled: SettingsService.data.appearance.darkMode

    IpcHandler {
        target: "nightLight"

        function toggle() { WallpaperService.toggleTemporaryDarkMode() }
    }
}
