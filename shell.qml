//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications

// Shell entry point. Instantiate top-level windows only and keep behavior in modules/services.
ShellRoot {
    id: root

    readonly property bool _systemMonitorHarnessEnabled:
        root._isSystemMonitorHarnessEnabled()
    readonly property bool _launcherServiceReady: LauncherService !== null

    function _isSystemMonitorHarnessEnabled() {
        const harnessMode = Quickshell.env("SYSTEM_MONITOR_HARNESS_MODE")
        if (typeof harnessMode === "string")
            return harnessMode.trim() !== ""

        return !!harnessMode
    }

    Component {
        id: _normalShellContent

        Item {
            BackgroundWindow {}
            BarWindow {}
            ContextMenuBackdrop {}
            WidgetPickerWindow {}
            WallpaperPickerWindow {}
            NotificationPopupWindow {}
            MediaControlPanel {}
        }
    }

    Loader {
        active: true
        source: root._systemMonitorHarnessEnabled ? "tests/qml/systemmonitor/SystemMonitorHarness.qml" : ""
        sourceComponent: root._systemMonitorHarnessEnabled ? null : _normalShellContent
    }
}
