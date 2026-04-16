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

    readonly property var _breakReminderService: BreakReminderService
    readonly property var _nightLightService: NightLightService
    readonly property var _powerProfileService: PowerProfileService

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
        }
    }

    Loader {
        active: true
        sourceComponent: _normalShellContent
    }
}
