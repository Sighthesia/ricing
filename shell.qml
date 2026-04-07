//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications
import qs.modules.sessioncontrol

// Shell entry point. Instantiate top-level windows only and keep behavior in modules/services.
ShellRoot {
    id: root

    readonly property var _breakReminderService: BreakReminderService

    Component.onCompleted: {
        LauncherService.ensureInitialized()
    }

    Component {
        id: _normalShellContent

        Item {
            BackgroundWindow {}
            ScreenCornerWindow {}
            BarWindow {}
            ContextMenuBackdrop {}
            WidgetPickerWindow {}
            WallpaperPickerWindow {}
            NotificationPopupWindow {}
            MediaControlPanel {}
            SessionControlWindow {}
        }
    }

    Loader {
        active: true
        sourceComponent: _normalShellContent
    }
}
