//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications
import qs.modules.launcher

// Shell entry point. Instantiate top-level windows only and keep behavior in modules/services.
ShellRoot {
    id: root

    readonly property bool _systemMonitorHarnessEnabled:
        root._isSystemMonitorHarnessEnabled()

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
            SettingsPanelWindow {}
            ContextMenuBackdrop {}
            WidgetPickerWindow {}
            WallpaperPickerWindow {}
            NotificationPopupWindow {}
            NotificationHistoryPanel {}
            LauncherPanel {}
            MediaControlPanel {}
        }
    }

    Loader {
        active: true
        source: root._systemMonitorHarnessEnabled ? "tests/qml/systemmonitor/SystemMonitorHarness.qml" : ""
        sourceComponent: root._systemMonitorHarnessEnabled ? null : _normalShellContent
    }
}
