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
        sourceComponent: _normalShellContent
    }
}
